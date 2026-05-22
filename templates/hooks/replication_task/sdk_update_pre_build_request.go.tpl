
// sdk_update_pre_build_request hook
//
// Sync the latest tags.
if delta.DifferentAt("Spec.Tags") {
    if err = rm.syncTags(ctx, desired, latest); err != nil {
        return nil, err
    }
}
if !delta.DifferentExcept("Spec.Tags") {
    return desired, nil
}

// sdk_update_pre_build_request hook
//
// Stop the replication task before updating it.
if shouldStopReplicationTask(latest.ko, delta) {
    stopReplicationTaskInput := newStopReplicationTaskRequestPayload(latest.ko)
    _, err := rm.sdkapi.StopReplicationTask(ctx, stopReplicationTaskInput)
    rm.metrics.RecordAPICall("UPDATE", "StopReplicationTask", err)
    if err != nil {
        return nil, err
    }
    // Record that we stopped for an update, not by user request
    latest.ko.Status.UpdateInProgress = aws.Bool(true)
    latest.ko.Status.TaskStatus = aws.String(replicationTaskStatusStopping)
    return latest, nil
}
