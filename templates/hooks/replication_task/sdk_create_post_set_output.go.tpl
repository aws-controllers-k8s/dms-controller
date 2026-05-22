
// sdk_create_post_set_output hook
//
// Ensure TableMappings, TaskSettings and TaskData are indented JSON for
// better readability
err = ensureJsonIndented(ko)
if err != nil {
    return nil, err
}
