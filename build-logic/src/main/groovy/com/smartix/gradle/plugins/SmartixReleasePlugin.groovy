package com.smartix.gradle.plugins

import org.gradle.api.Plugin
import org.gradle.api.Project

class SmartixReleasePlugin implements Plugin<Project> {

    @Override
    void apply(Project project) {
        project.tasks.register('smartixRelease', SmartixReleaseTask) {
            group = 'smartix'
        }
    }
}
