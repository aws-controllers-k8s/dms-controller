# Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may
# not use this file except in compliance with the License. A copy of the
# License is located at
#
#	 http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.

"""Utilities for working with DMS ReplicationInstance resources"""

import datetime
import time
import typing

import boto3
import pytest

DEFAULT_WAIT_UNTIL_DELETED_TIMEOUT_SECONDS = 60 * 40
DEFAULT_WAIT_UNTIL_DELETED_INTERVAL_SECONDS = 15

# Statuses to keep polling through during teardown: DMS won't accept the delete
# until an in-flight modification finishes, so these are expected, not failures.
_TOLERATED_TEARDOWN_STATUSES = frozenset({"available", "modifying"})


def wait_until_deleted(
    replication_instance_id: str,
    timeout_seconds: int = DEFAULT_WAIT_UNTIL_DELETED_TIMEOUT_SECONDS,
    interval_seconds: int = DEFAULT_WAIT_UNTIL_DELETED_INTERVAL_SECONDS,
) -> None:
    """Waits until a ReplicationInstance with the supplied ID is no longer
    returned from the DMS API.

    Usage::

        from e2e.replication_instance import wait_until_deleted

        wait_until_deleted(instance_id)

    Raises:
        pytest.fail upon timeout or if the instance enters an unexpected status
        (i.e. not "deleting" nor a status tolerated during teardown) while being
        removed.
    """
    now = datetime.datetime.now()
    timeout = now + datetime.timedelta(seconds=timeout_seconds)

    while True:
        if datetime.datetime.now() >= timeout:
            pytest.fail(
                "Timed out waiting for ReplicationInstance to be "
                "deleted in DMS API"
            )
        time.sleep(interval_seconds)

        latest = get(replication_instance_id)
        if latest is None:
            break

        status = latest['ReplicationInstanceStatus']
        if status == "deleting" or status in _TOLERATED_TEARDOWN_STATUSES:
            continue

        pytest.fail(
            "Unexpected status for ReplicationInstance that was deleted. "
            "Status is " + status
        )


def get(replication_instance_id: str) -> dict | None:
    """Returns a dict containing the ReplicationInstance record from the DMS API.

    If no such replication instance exists, returns None.
    """
    c = boto3.client('dms')
    try:
        resp = c.describe_replication_instances(
            Filters=[
                {
                    'Name': 'replication-instance-id',
                    'Values': [replication_instance_id],
                }
            ]
        )
        instances = resp.get('ReplicationInstances', [])
        if not instances:
            return None
        assert len(instances) == 1
        return instances[0]
    except c.exceptions.ResourceNotFoundFault:
        return None


def get_tags(replication_instance_arn: str) -> list | None:
    """Returns the TagList for a ReplicationInstance from the DMS API.

    If no such replication instance exists, returns None.
    """
    c = boto3.client('dms')
    try:
        resp = c.list_tags_for_resource(ResourceArn=replication_instance_arn)
        return resp['TagList']
    except c.exceptions.ResourceNotFoundFault:
        return None

