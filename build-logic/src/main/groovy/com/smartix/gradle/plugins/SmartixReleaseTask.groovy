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
    private final def versionProperties = ['version']

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
        checkoutDevelop()
        releaseMaster()
        releaseRelease()
        upVersionAndWriteToProps()
        releaseDevelop()
    }

    private void checkoutDevelop() {
        project.exec {
            commandLine 'git', 'checkout', developBranchName
        }
    }

    private void releaseMaster() {
        checkoutDevelop()
        project.exec {
            commandLine 'git', 'pull', 'origin', developBranchName
        }
        project.exec {
            commandLine 'git', 'checkout', masterBranchName
        }
        project.exec {
            commandLine 'git', 'pull', 'origin', masterBranchName
        }
        project.exec {
            commandLine 'git', 'merge', "origin/$developBranchName"
        }
        project.exec {
            commandLine 'git', 'push', 'origin', masterBranchName
        }
    }

    private void releaseRelease() {
        def releaseBranchName = "release/${project.property('version')}"
        checkoutDevelop()
        project.exec {
            commandLine 'git', 'branch', releaseBranchName
        }
        project.exec {
            commandLine 'git', 'checkout', releaseBranchName
        }
        project.exec {
            commandLine 'git', 'merge', "origin/$developBranchName"
        }
        project.exec {
            commandLine 'git', 'push', 'origin', releaseBranchName
        }
    }

    private void releaseDevelop() {
        checkoutDevelop()
        project.exec {
            commandLine 'git', 'commit', "-am \"Release ${project.property('version')}\""
        }
        project.exec {
            commandLine 'git', 'push', 'origin', developBranchName
        }
    }

    private void upVersionAndWriteToProps() {
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
