
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
// Stop the replication task when requested or before updating it.
if shouldStopReplicationTask(latest.ko, delta) {
    stopReplicationTaskInput := newStopReplicationTaskRequestPayload(latest.ko)
    _, err := rm.sdkapi.StopReplicationTask(ctx, stopReplicationTaskInput)
    rm.metrics.RecordAPICall("UPDATE", "StopReplicationTask", err)
    if err != nil {
        return nil, err
    }
    // Setting a transient state re-queues because not synced.
    latest.ko.Status.TaskStatus = aws.String(replicationTaskStatusStopping)
    return latest, nil
}

// sdk_update_pre_build_request hook
//
// Start the replication task when requested or after updating it.
if !delta.DifferentExcept("Spec.StartReplicationTask") {
    if shouldStartReplicationTask(latest.ko) {
        startReplicationTaskInput := newStartReplicationTaskRequestPayload(latest.ko)
        _, err := rm.sdkapi.StartReplicationTask(ctx, startReplicationTaskInput)
        rm.metrics.RecordAPICall("UPDATE", "StartReplicationTask", err)
        if err != nil {
            return nil, err
        }
        // Setting a transient state re-queues because not synced.
        latest.ko.Status.TaskStatus = aws.String(replicationTaskStatusStarting)
        return latest, nil
    }
}
