
// sdk_delete_post_request hook
//
// Wait for the resource to be deleted before setResourceUnmanaged.
if err != nil {
    return nil, err
}
r.ko.Status.TaskStatus = aws.String(replicationTaskStatusDeleting)
return r, ackrequeue.NeededAfter(
    errors.New(fmt.Sprintf("resource is in %s state", *r.ko.Status.TaskStatus)),
    30*time.Second)
