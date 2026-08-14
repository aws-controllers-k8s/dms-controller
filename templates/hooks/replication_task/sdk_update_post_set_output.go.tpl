
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
// Force another evaluation of the update path when StartReplicationTask
// is true.
if startRequested(ko) {
    return &resource{ko}, ackrequeue.NeededAfter(fmt.Errorf("resource updated, requeue for start"), time.Second)
}
