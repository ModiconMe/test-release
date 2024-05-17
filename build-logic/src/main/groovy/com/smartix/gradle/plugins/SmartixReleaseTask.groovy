package com.smartix.gradle.plugins

import org.gradle.api.DefaultTask
import org.gradle.api.Project
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.TaskAction

class SmartixReleaseTask extends DefaultTask {

    @Input
    private final developBranchName = 'develop'
    @Input
    private final def masterBranchName = 'main'
    @Input
    private final def versionProperties = ['version', 'version1']

    def getDevelopBranchName() {
        return developBranchName
    }

    def getMasterBranchName() {
        return masterBranchName
    }

    def getVersionProperties() {
        return versionProperties
    }

    @TaskAction
    void apply() {
        checkoutDevelop(project)
        release(project, masterBranchName)
        release(project, "release/${project.property('version')}")
        upVersionAndWriteToProps(project)
        releaseDevelop(project)
    }

    private void checkoutDevelop(Project project) {
        project.exec {
            commandLine 'git', 'checkout', developBranchName
        }
    }

    private void release(Project project, String releaseBranch) {
        checkoutDevelop(project)
        project.exec {
            commandLine 'git', 'pull', 'origin', developBranchName
        }
        project.exec {
            commandLine 'git', 'checkout', releaseBranch
        }
        project.exec {
            commandLine 'git', 'merge', "origin/$developBranchName"
        }
        project.exec {
            commandLine 'git', 'push', 'origin', releaseBranch
        }
    }

    private void releaseDevelop(Project project) {
        checkoutDevelop(project)
        project.exec {
            commandLine 'git', 'commit', "-am \"Release ${project.property('version')}\""
        }
        project.exec {
            commandLine 'git', 'push', 'origin', developBranchName
        }
    }

    private void upVersionAndWriteToProps(Project project) {
        def props = new Properties()
        def file = project.file("gradle.properties")
        file.withInputStream { props.load(it) }
        def versionProperty = props.get('version') as String
        def versionArray = versionProperty.split('\\.')

        if (versionArray.size() != 3) {
            throw new IllegalArgumentException('Wrong version: ' + versionProperty)
        }

        def firstDigit = versionArray[0] as int
        def secondDigit = versionArray[1] as int
        def thirdDigit = versionArray[2] as int

        if (firstDigit > 9 || firstDigit < 0 || secondDigit > 9 || secondDigit < 0 || thirdDigit > 9 || thirdDigit < 0) {
            throw new IllegalArgumentException('Wrong version: ' + versionProperty)
        }

        if (secondDigit == 9 && thirdDigit == 9) {
            firstDigit++
            secondDigit = 0
            thirdDigit = 0
        } else if (thirdDigit == 9) {
            secondDigit++
            thirdDigit = 0
        } else if (thirdDigit < 9) {
            thirdDigit++
        }

        def newVersion = "$firstDigit.$secondDigit.$thirdDigit"

        for (final String name in versionProperties) {
            props.setProperty(name, newVersion)
        }
        println props

        props.store(file.newWriter(), null)
    }
}
