// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License"). You may
// not use this file except in compliance with the License. A copy of the
// License is located at
//
//     http://aws.amazon.com/apache2.0/
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.

package certificate

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"reflect"
	"sort"
	"strings"
	"sync"
	"testing"

	ackv1alpha1 "github.com/aws-controllers-k8s/runtime/apis/core/v1alpha1"
	ackmetrics "github.com/aws-controllers-k8s/runtime/pkg/metrics"
	"github.com/aws/aws-sdk-go-v2/aws"
	svcsdk "github.com/aws/aws-sdk-go-v2/service/databasemigrationservice"

	svcapitypes "github.com/aws-controllers-k8s/dms-controller/apis/v1alpha1"
)

// recordedTagsCall is a DMS tagging request received by the fake endpoint.
type recordedTagsCall struct {
	Op      string
	Tags    []svcTagJSON `json:"Tags"`
	TagKeys []string     `json:"TagKeys"`
}

type svcTagJSON struct {
	Key   string `json:"Key"`
	Value string `json:"Value"`
}

// fakeTagsEndpoint is an httptest server that records the tagging calls made
// by a resourceManager and replies with empty successful responses.
type fakeTagsEndpoint struct {
	mu    sync.Mutex
	calls []recordedTagsCall
}

func (f *fakeTagsEndpoint) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	body, _ := io.ReadAll(r.Body)
	call := recordedTagsCall{}
	_ = json.Unmarshal(body, &call)
	// X-Amz-Target has the form "AmazonDMSv20160101.<Operation>".
	target := r.Header.Get("X-Amz-Target")
	call.Op = target[strings.LastIndex(target, ".")+1:]

	f.mu.Lock()
	f.calls = append(f.calls, call)
	f.mu.Unlock()

	w.Header().Set("Content-Type", "application/x-amz-json-1.1")
	_, _ = w.Write([]byte("{}"))
}

// newTestResourceManager returns a resourceManager whose DMS client talks to
// a fake endpoint, along with the endpoint so tests can inspect its calls.
func newTestResourceManager(t *testing.T) (*resourceManager, *fakeTagsEndpoint) {
	t.Helper()
	endpoint := &fakeTagsEndpoint{}
	srv := httptest.NewServer(endpoint)
	t.Cleanup(srv.Close)

	client := svcsdk.NewFromConfig(aws.Config{
		Region:      "us-east-1",
		Credentials: aws.AnonymousCredentials{},
	}, func(o *svcsdk.Options) {
		o.BaseEndpoint = aws.String(srv.URL)
	})
	return &resourceManager{
		metrics: ackmetrics.NewMetrics("dms"),
		sdkapi:  client,
	}, endpoint
}

// newTestCertificates returns the latest and desired resources for a tag sync.
func newTestCertificates(
	latestTags []*svcapitypes.Tag,
	desiredTags []*svcapitypes.Tag,
) (*resource, *resource) {
	arn := ackv1alpha1.AWSResourceName("arn:aws:dms:us-east-1:123456789012:cert:TEST")
	newCert := func(tags []*svcapitypes.Tag) *resource {
		return &resource{ko: &svcapitypes.Certificate{
			Spec: svcapitypes.CertificateSpec{Tags: tags},
			Status: svcapitypes.CertificateStatus{
				ACKResourceMetadata: &ackv1alpha1.ResourceMetadata{ARN: &arn},
			},
		}}
	}
	return newCert(desiredTags), newCert(latestTags)
}

func testTag(key, value *string) *svcapitypes.Tag {
	return &svcapitypes.Tag{Key: key, Value: value}
}

func TestSyncTags(t *testing.T) {
	tests := []struct {
		name        string
		latest      []*svcapitypes.Tag
		desired     []*svcapitypes.Tag
		wantOps     []string
		wantAdd     map[string]string
		wantRemoved []string
	}{
		{
			name:    "no-op when tags are unchanged",
			latest:  []*svcapitypes.Tag{testTag(aws.String("env"), aws.String("prod"))},
			desired: []*svcapitypes.Tag{testTag(aws.String("env"), aws.String("prod"))},
		},
		{
			name:    "adds a new tag",
			latest:  nil,
			desired: []*svcapitypes.Tag{testTag(aws.String("env"), aws.String("prod"))},
			wantOps: []string{"AddTagsToResource"},
			wantAdd: map[string]string{"env": "prod"},
		},
		{
			name:        "removes a tag missing from desired",
			latest:      []*svcapitypes.Tag{testTag(aws.String("env"), aws.String("prod"))},
			desired:     nil,
			wantOps:     []string{"RemoveTagsFromResource"},
			wantRemoved: []string{"env"},
		},
		{
			name:    "changed value is added without removal",
			latest:  []*svcapitypes.Tag{testTag(aws.String("env"), aws.String("dev"))},
			desired: []*svcapitypes.Tag{testTag(aws.String("env"), aws.String("prod"))},
			wantOps: []string{"AddTagsToResource"},
			wantAdd: map[string]string{"env": "prod"},
		},
		{
			name: "add and remove in the same sync",
			latest: []*svcapitypes.Tag{
				testTag(aws.String("env"), aws.String("prod")),
				testTag(aws.String("old"), aws.String("x")),
			},
			desired: []*svcapitypes.Tag{
				testTag(aws.String("env"), aws.String("prod")),
				testTag(aws.String("new"), aws.String("y")),
			},
			wantOps:     []string{"RemoveTagsFromResource", "AddTagsToResource"},
			wantAdd:     map[string]string{"new": "y"},
			wantRemoved: []string{"old"},
		},
		{
			name: "nil keys are ignored without panicking",
			latest: []*svcapitypes.Tag{
				testTag(nil, aws.String("x")),
				testTag(aws.String("team"), aws.String("db")),
			},
			desired: []*svcapitypes.Tag{
				testTag(nil, aws.String("y")),
				testTag(aws.String("team"), aws.String("db")),
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rm, endpoint := newTestResourceManager(t)
			desired, latest := newTestCertificates(tc.latest, tc.desired)

			if err := rm.syncTags(context.Background(), desired, latest); err != nil {
				t.Fatalf("syncTags() returned error: %v", err)
			}

			endpoint.mu.Lock()
			calls := endpoint.calls
			endpoint.mu.Unlock()

			var gotOps []string
			var gotAdd map[string]string
			var gotRemoved []string
			for _, call := range calls {
				gotOps = append(gotOps, call.Op)
				switch call.Op {
				case "AddTagsToResource":
					gotAdd = make(map[string]string, len(call.Tags))
					for _, tag := range call.Tags {
						gotAdd[tag.Key] = tag.Value
					}
				case "RemoveTagsFromResource":
					gotRemoved = append(gotRemoved, call.TagKeys...)
				}
			}
			sort.Strings(gotRemoved)

			if !reflect.DeepEqual(gotOps, tc.wantOps) {
				t.Errorf("API calls = %v, want %v", gotOps, tc.wantOps)
			}
			if !reflect.DeepEqual(gotAdd, tc.wantAdd) {
				t.Errorf("added tags = %v, want %v", gotAdd, tc.wantAdd)
			}
			if !reflect.DeepEqual(gotRemoved, tc.wantRemoved) {
				t.Errorf("removed tag keys = %v, want %v", gotRemoved, tc.wantRemoved)
			}
		})
	}
}
