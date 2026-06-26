
    // delta_pre_compare hook
    //
    // When autoMinorVersionUpgrade is enabled and the engine version
    // difference is only a minor version change (same major version),
    // normalize the desired engine version to match the latest. This
    // prevents the delta from firing on every reconcile when AWS
    // auto-upgrades the minor version.
    if a.ko.Spec.EngineVersion != nil && b.ko.Spec.EngineVersion != nil {
        autoMinorVersionUpgrade := true
        if a.ko.Spec.AutoMinorVersionUpgrade != nil {
            autoMinorVersionUpgrade = *a.ko.Spec.AutoMinorVersionUpgrade
        }
        if !requiresEngineVersionUpdate(a.ko.Spec.EngineVersion, b.ko.Spec.EngineVersion, autoMinorVersionUpgrade) {
            a.ko.Spec.EngineVersion = b.ko.Spec.EngineVersion
        }
    }
