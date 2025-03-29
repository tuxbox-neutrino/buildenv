<!-- LANGUAGE_LINKS_START -->
[🇩🇪 German](README_de.md) | <span style="color: grey;">🇬🇧 English</span>
<!-- LANGUAGE_LINKS_END -->

This script serves as a tool to simplify the creation of a development environment and the build process for images that run with Neutrino as a user interface on different hardware platforms. It automates some steps that are required to set up a consistent and functional development and build environment by pre-configuring the necessary dependencies and basic configurations as well as meta-layers and enabling custom settings. The script aims to provide a foundation on which to build and experiment to create, update, and maintain your own customized versions of Tuxbox-Neutrino images.

[![Version](https://img.shields.io/badge/version-0.5.7-blue.svg)](https://github.com/tuxbox-neutrino/buildenv)

- [1. Preparation](#1-preparation)
	- [1.1 Install required host packages](#11-install-required-host-packages)
		- [1.1.1 Recommended additional packages for graphical support and analysis](#111-recommended-additional-packages-for-graphical-support-and-analysis)
	- [1.2 Prepare Git (if necessary)](#12-prepare-git-if-necessary)
	- [1.3 Clone Init script](#13-clone-init-script)
	- [1.4 Run Init script](#14-run-init-script)
	- [1.5 Structure of the build environment](#15-structure-of-the-build-environment)
- [2. Building an image](#2-building-an-image)
	- [2.1 Choose a box](#21-choose-a-box)
	- [2.2 Start the environment script](#22-start-the-environment-script)
	- [2.3 Create an image](#23-create-an-image)
- [3. Updates](#3-updates)
	- [3.1 Update image](#31-update-image)
	- [3.2 Update package](#32-update-package)
	- [3.3 Update meta-layer repositories](#33-update-meta-layer-repositories)
- [4. Custom modifications](#4-custom-modifications)
	- [4.1 Configuration](#41-configuration)
		- [4.1.1 Configuration files](#411-configuration-files)
		- [4.1.2 bblayers.conf](#412-bblayersconf)
		- [4.1.3 Reset configuration](#413-reset-configuration)
	- [4.3 Recipes](#43-recipes)
	- [4.4 Packages](#44-packages)
		- [4.4.1 Edit source code in workspace (example)](#441-edit-source-code-in-workspace-example)
- [5. Force rebuilding a single package](#5-force-rebuilding-a-single-package)
- [6. Force complete image build](#6-force-complete-image-build)
- [7. License](#7-license)
- [8. Further information](#8-further-information)

## 1. Preparation

It is recommended to use the designated Docker container, as this already takes care of significant steps to get started with as few adjustments to your system as possible. [See docker-buildenv](https://github.com/tuxbox-neutrino/docker-buildenv). In this case, you can begin directly [with the initialization](#14-run-init-script).

**NOTE:** [docker-buildenv](https://github.com/tuxbox-neutrino/docker-buildenv) completely replaces the [Tuxbox-Builder](https://sourceforge.net/projects/n4k/files/Tuxbox-Builder) VM. Its maintenance will no longer be continued.

Paths specified here are based on defaults created by the Init script. Some entries are displayed as ```<placeholder>``` which must be adjusted locally. [See schema](#14-run-init-script)

### 1.1 Install required host packages

**Note:** For other distributions, see: [Yocto Project Quick Build](https://docs.yoctoproject.org/3.2.4/ref-manual/ref-system-requirements.html#supported-linux-distributions)

Debian 11

```bash
sudo apt-get install -y gawk wget git-core diffstat unzip texinfo gcc-multilib build-essential \
chrpath socat cpio python python3 python3-pip python3-pexpect xz-utils debianutils \
iputils-ping python3-git python3-jinja2 libegl1-mesa pylint3 xterm subversion locales-all \
libxml2-utils ninja-build default-jre clisp libcapstone4 libsdl2-dev doxygen
```

Debian 12

```bash
sudo apt-get install -y gawk wget git diffstat unzip texinfo gcc-multilib build-essential \
chrpath socat cpio python3 python3-pip python3-pexpect xz-utils debianutils iputils-ping \
python3-git python3-jinja2 libegl1-mesa pylint3 xterm subversion locales-all libxml2-utils \
ninja-build default-jre clisp libcapstone4 libsdl2-dev doxygen
```

#### 1.1.1 Recommended additional packages for graphical support and analysis

```bash
sudo apt-get install -y gitk git-gui meld cppcheck clazy kdevelop
```

### 1.2 Prepare Git (if necessary)

The init script uses Git to clone the meta-layer repositories. If you don't have Git configured yet, please set up your global Git user data, otherwise you'll receive unnecessary notices while the script is running.

```bash
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
```

### 1.3 Clone Init script

```bash
git clone https://github.com/tuxbox-neutrino/buildenv.git && cd buildenv
```

### 1.4 Run Init script

```bash
./init && cd poky-3.2.4
```

### 1.5 Structure of the build environment

After [step 1.4](#14-run-init-script), the structure should look approximately like this:

```
.buildenv
 ├── dist                          <-- Release folder for http server (if set up) http://localhost, http://localhost:8080, needed for IPK feeds and images
 │   └── {DISTRO_VERSION}          <-- here are the generated images and packages (symlinks point to the deploy directories within the build subdirectories)
 :
 ├── init.sh                       <-- init script
 ├── local.conf.common.inc         <-- global user configuration, is included in the custom configuration
 :
 ├── log                           <-- folder for logs, contains logs for each execution of the init script
 :
 └── poky-{DISTRO_VERSION}         <-- After step 1.4 you are here. This is where the build system core and the meta-layers are located
     │
     :
     └── build                     <-- Here are the build subdirectories, after step 2.2 you will be in one of these build subdirectories
         ├── <machine x>           <-- Build subdirectory for machine type x
         │   ├── conf              <-- Folder for layer and custom configuration
         │   │   └── bblayers.conf <-- Configuration file for included meta-layers
         │   │   └── local.conf    <-- custom configuration for a machine type
         │   :
         │   ├── (tmp)             <-- Working directory, automatically created during building
         │   └── (workspace)       <-- Workspace, created when running devtool
         :
         └── <machine y>           <-- Another build subdirectory for machine type y
```

## 2. Building an image

Make sure you are here as shown in the [schema](#15-structure-of-the-build-environment):

```
poky-{DISTRO_VERSION}
```

### 2.1 Choose a box

Display a list of available devices:

```bash
ls build
```

### 2.2 Start the environment script

Run the environment script once for the desired box from the list! You will then automatically be taken to the appropriate build subdirectory.

```bash
. ./oe-init-build-env build/<machine>
```

As long as you are now in the generated environment within the opened shell in the desired build subdirectory, you don't need to run this script again and can [step 2.3](#23-create-an-image) build images or any packages.

**Note:** You can also create additional shells and thus build environments for other box types in parallel and switch to the corresponding terminal as needed and also build in parallel, if your system can handle it.

### 2.3 Create an image

```bash
bitbake neutrino-image
```

This may take a while. Some warnings can be ignored. Error messages related to setscene tasks are not a problem, but errors during build and package tasks will abort the process in most cases. [Please report the error or share your solution in this case](https://forum.tuxbox-neutrino.org/forum/viewforum.php?f=77). Help is much appreciated.

When everything is done, a message similar to this should appear:

```bash
"NOTE: Tasks Summary: Attempted 4568 tasks of which 4198 didn't need to be rerun and all succeeded."
```

<span style="color: green;">That's it ...</span>

You can find results under:

```bash
buildenv/poky-{DISTRO_VERSION}/build/<machine>/tmp/deploy
```

or in the release directory:

```bash
buildenv/dist/<Image-Version>/<machine>/
```

If a web server is set up that points to the release directory:

```bash
http://localhost/{DISTRO_VERSION} or with port number http://localhost:8080/{DISTRO_VERSION}
```

## 3. Updates

Manual updates of packages are not required. This is done automatically with each target called with Bitbake. This also applies to possible dependencies. If you want full control over specific package sources, you can place them for each package in the designated workspace, see [4.4 Packages](#44-packages).
If no updates are necessary, the builds are automatically skipped.

### 3.1 Update image

```bash
bitbake neutrino-image
```

### 3.2 Update package

```bash
bitbake <package>
```

### 3.3 Update meta-layer repositories

Running the init script with the ```--update``` parameter updates the included meta-layers to the state of the remote repositories.

```bash
./init --update
```

If you have made changes to the meta-layers, non-committed changes should be temporarily stashed or rebased onto the local repository by triggered update routines of the init script. Of course, you can manually update your local meta-layers for meta-neutrino and machine layer repositories. However, conflicts must always be resolved manually.

**Note:** Configuration files remain essentially untouched, but possible variable names will be migrated. New or changed settings will not be modified. Please check the configuration if necessary.

## 4. Custom modifications

### 4.1 Configuration

It is recommended to build for the first time without changed configuration files to get an impression of how the build process works and to see the results as quickly as possible.
The setting options are very extensive and not really manageable for beginners. However, OpenEmbedded, especially the Yocto Project, is very comprehensively documented and offers the best source of information.

#### 4.1.1 Configuration files

> ~/buildenv/poky-3.2.4/build/```<machine>```/conf/local.conf

This file is located in the build directory of the respective machine type and is the actual custom configuration file originally intended for this purpose by the build system. However, this local.conf contains only a few lines in this environment and includes a global configuration. This file is **only** valid for the machine type it supports. Here you can therefore make supplementary entries that are only intended for the machine type. [See also schema](#14-run-init-script)

> ~/buildenv/local.conf.common.inc

This file contains settings that apply to all machine types and is created when the init script is first executed from the template ```~/buildenv/local.conf.common.inc.sample```.

The ```./build/<machine>/conf/local.conf``` intended by the build system could be used as the primary configuration file for each machine type separately, as originally intended by the build system, but this would unnecessarily increase the maintenance effort. That's why ```~/buildenv/local.conf.common.inc``` is only included in ```./build/<machine>/conf/local.conf```.

**Note on** ```~/buildenv/local.conf.common.inc.sample```**:** This is just a template and should remain untouched to avoid possible conflicts when updating the build script repository and to see what might have changed.

After updating the build script repository, new or changed options may have been added or removed that are not included in the included configuration file. This case should be considered in your own configuration and checked and adjusted if necessary.

#### 4.1.2 bblayers.conf

> ~/buildenv/poky-3.2.4/build/```<machine>```/conf/bblayers.conf

This file is normally adjusted when running the init script for the first time and usually only needs to be adjusted if you want to add, remove, or replace layers.

#### 4.1.3 Reset configuration

If you want to reset your machine configurations, please rename the conf directory (deleting is not recommended) and run the init script again.

```bash
~/mv ~/buildenv/poky-3.2.4/build/<machine>/conf ~/buildenv/poky-3.2.4/build/<machine>/conf.01
~/cd ~/buildenv
~/./init
```

### 4.3 Recipes

**Unless you are directly involved in the development of the Poky layers, do not change anything in the official Poky layers (meta-layers)! This is explicitly not recommended by the Yocto Project, as you run the risk of losing all your work when updating and creating incompatibilities or conflicts that can be difficult to maintain. The usual procedure to complete, extend, or override existing official recipes is to [use .bbappend files](https://docs.yoctoproject.org/3.2.4/dev-manual/dev-manual-common-tasks.html#using-bbappend-files-in-your-layer).**

Alternatively, although also not really recommended, you could include copies of official recipes in your own meta-layers and customize them, as these are usually preferred by the build system. In such a case, however, you are responsible for keeping these recipes up-to-date, which can unnecessarily increase the maintenance effort.

For recipes from your own meta-layers such as meta-neutrino or the machine layers, the same principle applies. But if you want to [actively work on the recipes](https://docs.yoctoproject.org/current/ref-manual/devtool-reference.html#modifying-an-existing-recipe), feel free to do so.

### 4.4 Packages

If you want full control over a package's source code, e.g. to fix something or actively develop, the source code you want to work on should be moved to the workspace. See: [Example for Neutrino](#441-edit-source-code-in-workspace-example)

See [devtool](https://docs.yoctoproject.org/current/ref-manual/devtool-reference.html) and especially [devtool modify](https://docs.yoctoproject.org/current/ref-manual/devtool-reference.html#modifying-an-existing-recipe). In the workspace, you have the guarantee that the source code will not be touched by the build system. If you don't observe this, it can happen, for example, that changed source code will be deleted or modified again and again. Therefore, your own adjustments may be lost or become incompatible. In the local standard configuration, [rm_work](https://docs.yoctoproject.org/ref-manual/classes.html#ref-classes-rm-work) is activated, which ensures that after each completed build of a package, the respective working directory is cleaned up, so that except for some logs, nothing will remain.

#### 4.4.1 Edit source code in workspace (example)

Neutrino is used here as an example, but this procedure essentially applies to all other packages.

```bash
~/buildenv/poky-3.2.4/build/hd61$ devtool modify neutrino
NOTE: Starting bitbake server...54cf81d24c147d888c"
...
workspace            = "3.2.4:13143ea85a1ab7703825c0673128c05845b96cb5"

Initialising tasks: 100% |###################################################################################################################################################################################################| Time: 0:00:01
Sstate summary: Wanted 0 Found 0 Missed 0 Current 10 (0% match, 100% complete)
NOTE: Executing Tasks
NOTE: Tasks Summary: Attempted 83 tasks of which 80 didn't need to be rerun and all succeeded.
INFO: Adding local source files to srctree...
INFO: Source tree extracted to /home/<user>/buildenv/poky-3.2.4/build/hd61/workspace/sources/neutrino
INFO: Recipe neutrino-mp now set up to build from /home/<user>/buildenv/poky-3.2.4/build/hd61/workspace/sources/neutrino
```

Under ```/buildenv/poky-3.2.4/build/hd61/workspace/sources/neutrino``` is now the source code for Neutrino. You can then work on it there. This means that the build system no longer clones or automatically updates the Neutrino sources from the remote Git repo on its own, but from now on only uses the local sources within the workspace that you have to manage yourself. This is a Git repo created by devtool, in which you can include the original remote repository if this is not already the case.

If you now execute...

```bash
bitbake neutrino
```

...Neutrino will from now on only be built from the local repo in the workspace:

```bash
NOTE: Started PRServer with DBfile: /home/<user>/buildenv/poky-3.2.4/build/hd61/cache/prserv.sqlite3, IP: 127.0.0.1, PORT: 34211, PID: 56838
...
workspace            = "3.2.4:13143ea85a1ab7703825c0673128c05845b96cb5"

Initialising tasks: 100% |###################################################################################################################################################################################################| Time: 0:00:01
Sstate summary: Wanted 122 Found 116 Missed 6 Current 818 (95% match, 99% complete)
NOTE: Executing Tasks
NOTE: neutrino-mp: compiling from external source tree /home/<user>/buildenv/poky-3.2.4/build/hd61/workspace/sources/neutrino
NOTE: Tasks Summary: Attempted 2756 tasks of which 2741 didn't need to be rerun and all succeeded.
```

**Note!** In the special case of Neutrino, it is advisable to transfer not only its source code but also the associated ```libstb-hal``` to the workspace.

```bash
devtool modify libstb-hal
```

## 5. Force rebuilding a single package

In some cases, a target may abort for whatever reason. But you should by no means panic and therefore delete the working folder and the expensive sstate-cache. Cleanups can be performed for each target individually without flattening an otherwise functioning system.

Especially defective archive URLs can lead to aborts. However, these errors are always displayed and you can check the URL. Often it's just the servers and they work again after a few minutes.

To ensure whether the recipe in question actually has a problem, it makes sense to completely clean the target in question and rebuild it. To achieve this, all associated package, build, and cache data must be cleaned.

```bash
bitbake -c cleansstate <target>

```
then rebuild:

```bash
bitbake <target>
```

## 6. Force complete image build

The init script provides the `--reset` option for this.

```bash
./init --reset
# Follow instructions

```

You can also achieve this manually by renaming the tmp directory in the respective build subdirectory. You can delete it later if you want to free up storage space or if you are sure that you no longer need the directory:

```bash
mv tmp tmp.01
```

Then have the image rebuilt:

```bash
bitbake neutrino-image
```

If you haven't deleted the cache, the image should be built in a relatively short time. That's why it's recommended to keep the cache. The directory where the cache is located is set via the variable ```${SSTATE_DIR}``` and can be adjusted in the configuration.

This directory is quite valuable and only in rare cases is it necessary to delete this directory. Please note that the build process takes much more time after deleting the cache.

## 7. License

```
MIT License
```

## 8. Further information

More information about the Yocto build system:

* https://docs.yoctoproject.org