
// sdk_update_post_set_output hook
//
// Ensure TableMappings, TaskSettings and TaskData are indented JSON for
// better readability
err = ensureJsonIndented(ko)
if err != nil {
    return nil, err
}

// sdk_update_post_set_output hook
//
// Reset Status.UpdateInProgress so the next sync can start the
// task again if needed.
ko.Status.UpdateInProgress = nil

// sdk_update_post_set_output hook
//
// If the replication task is not in a steady state, requeue more frequently.
if !hasSteadyState(ko) {
    ackcondition.SetSynced(&resource{ko}, corev1.ConditionFalse,
        aws.String(fmt.Sprintf("ReplicationTask is in %v state", *ko.Status.TaskStatus)), nil)
    return &resource{ko}, nil
}
