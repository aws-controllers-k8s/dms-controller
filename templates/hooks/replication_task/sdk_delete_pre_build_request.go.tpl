
// sdk_delete_pre_build_request hook
//
// Do not attempt to delete the resource if it is already in the
// process of being deleted.
if r.ko.Status.TaskStatus != nil && *r.ko.Status.TaskStatus == replicationTaskStatusDeleting {
    return r, ackrequeue.NeededAfter(
        errors.New(fmt.Sprintf("resource is in %s state", *r.ko.Status.TaskStatus)),
        60*time.Second)
}

// sdk_delete_pre_build_request hook
//
// Stop the replication task before deleting it.
if shouldStopReplicationTask(r.ko, nil) {
    stopReplicationTaskInput := newStopReplicationTaskRequestPayload(r.ko)
    _, err := rm.sdkapi.StopReplicationTask(ctx, stopReplicationTaskInput)
    rm.metrics.RecordAPICall("UPDATE", "StopReplicationTask", err)
    if err != nil {
        return nil, err
    }
    r.ko.Status.TaskStatus = aws.String(replicationTaskStatusStopping)
}
