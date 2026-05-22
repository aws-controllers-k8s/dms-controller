
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
