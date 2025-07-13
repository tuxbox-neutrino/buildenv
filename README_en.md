<!-- LANGUAGE_LINKS_START -->
[🇩🇪 German](README_de.md) | <span style="color: grey;">🇬🇧 English</span>
<!-- LANGUAGE_LINKS_END -->

This script serves as a tool to simplify setting up a development environment and the build process for images that use Neutrino as their user interface on different hardware platforms. It automates several of the steps needed to create a consistent, functional development and build environment by pre‑installing the necessary dependencies, basic configurations, and meta‑layers, while still letting you add custom settings. The script aims to give you a solid base on which you can build and experiment in order to create, update, and maintain your own customised versions of Tuxbox‑Neutrino images.

* [1. Preparation](#1-preparation)

  * [1.1 Install required host packages](#11-install-required-host-packages)

    * [1.1.1 Recommended additional packages for GUI support and analysis](#111-recommended-additional-packages-for-gui-support-and-analysis)
  * [1.2 Prepare Git (if necessary)](#12-prepare-git-if-necessary)
  * [1.3 Clone the init script](#13-clone-the-init-script)
  * [1.4 Run the init script](#14-run-the-init-script)
  * [1.4.1 Structure of the build environment](#141-structure-of-the-build-environment)
* [2. Build an image](#2-build-an-image)

  * [2.1 Choose a box](#21-choose-a-box)
  * [2.2 Start the environment script](#22-start-the-environment-script)
  * [2.3 Create the image](#23-create-the-image)
* [3. Updating](#3-updating)

  * [3.1 Update an image](#31-update-an-image)
  * [3.2 Update a package](#32-update-a-package)
  * [3.3 Update meta‑layer repositories](#33-update-meta-layer-repositories)
* [4. Customisation](#4-customisation)

  * [4.1 Configuration](#41-configuration)

    * [4.1.1 Configuration files](#411-configuration-files)
    * [4.1.2 bblayers.conf](#412-bblayersconf)
    * [4.1.3 Reset configuration](#413-reset-configuration)
  * [4.3 Recipes](#43-recipes)
  * [4.4 Packages](#44-packages)

    * [4.4.1 Edit source code in the workspace (example)](#441-edit-source-code-in-the-workspace-example)
* [5. Force a rebuild of a single package](#5-force-a-rebuild-of-a-single-package)
* [6. Force a complete image build](#6-force-a-complete-image-build)
* [7. Licence](#7-licence)
* [8. Further information](#8-further-information)

## 1. Preparation

It is recommended to use the dedicated Docker container, because it already covers the essential steps so that you can start with as few adjustments to your host system as possible. See [docker-buildenv](https://github.com/tuxbox-neutrino/docker-buildenv). In that case you can jump straight to [initialisation](#14-run-the-init-script).

**NOTE:** [docker-buildenv](https://github.com/tuxbox-neutrino/docker-buildenv) completely replaces the [Tuxbox‑Builder](https://sourceforge.net/projects/n4k/files/Tuxbox-Builder) VM, which is no longer maintained.

The paths given here are based on defaults created by the init script. Some entries are shown as `<placeholder>` and have to be adapted locally. See [schema](#14-run-the-init-script).

### 1.1 Install required host packages

**Note:** When using other distributions see: [Yocto Project Quick Build](https://docs.yoctoproject.org/3.2.4/ref-manual/ref-system-requirements.html#supported-linux-distributions)

Debian 11

```bash
sudo apt-get install -y gawk wget git-core diffstat unzip texinfo gcc-multilib build-essential \
chrpath socat cpio python python3 python3-pip python3-pexpect xz-utils debianutils \
iputils-ping python3-git python3-jinja2 libegl1-mesa pylint3 xterm subversion locales-all \
libxml2-utils ninja-build default-jre clisp libcapstone4 libsdl2-dev doxygen
```

Debian 12

```bash
sudo apt-get install -y gawk wget git diffstat unzip texinfo gcc-multilib build-essential \
chrpath socat cpio python3 python3-pip python3-pexpect xz-utils debianutils iputils-ping \
python3-git python3-jinja2 libegl1-mesa pylint3 xterm subversion locales-all libxml2-utils \
ninja-build default-jre clisp libcapstone4 libsdl2-dev doxygen
```

#### 1.1.1 Recommended additional packages for GUI support and analysis

```bash
sudo apt-get install -y gitk git-gui meld cppcheck clazy kdevelop
```

### 1.2 Prepare Git (if necessary)

The init script uses Git to clone the meta‑layer repositories. If you do not yet have a configured Git installation, please set up your global Git user data, otherwise you will repeatedly see warnings while the script is running.

```bash
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
```

### 1.3 Clone the init script

```bash
git clone https://github.com/tuxbox-neutrino/buildenv.git && cd buildenv
```

### 1.4 Run the init script

```bash
./init && cd poky-3.2.4
```

### 1.4.1 Structure of the build environment

After [step 1.4](#14-run-the-init-script) your directory tree should look roughly like this:

````
.buildenv
 ├── dist                          <-- Public folder for your HTTP server (if configured) http://localhost or http://localhost:8080; required for IPK feeds and images
 │   └── {DISTRO_VERSION}          <-- generated images and packages live here (symlinks point to the deploy directories inside the build sub‑directories)
 :
 ├── init.sh                       <-- the init script
 ├── local.conf.common.inc         <-- global user configuration, included by the per‑machine configuration
 :
 ├── log                           <-- log folder, contains a log for every run of the init script
 :
 └── poky-{DISTRO_VERSION}         <-- after step 1.4 you are here. This contains the build system core and the meta‑layers
     │
     :
     └── build                     <-- build sub‑directories live here; after step 2.2 you are inside one of the machine build sub‑directories
         ├── <machine x>           <-- build sub‑directory for machine type x
         │   ├── conf              <-- configuration folder for layers and user settings
         │   │   ├── bblayers.conf <-- configuration file for the meta‑layers
         │   │   └── local.conf    <-- user configuration for this machine type
         │   :
         │   ├── (tmp)             <-- working directory automatically created by BitBake when building targets
         │   └── (workspace)       <-- workspace automatically created by ```devtool modify```
         :
         └── <machine y>           <-- another build sub‑directory for machine type y
````

## 2. Build an image

Make sure you are inside the `poky` directory as shown in the [schema](#141-structure-of-the-build-environment):

```
poky-{DISTRO_VERSION}
```

### 2.1 Choose a box

Show list of available devices:

```bash
ls build
<machine>  <machine1>  <machine2>  <machine3>...
```

**Note:** Only the machine types shown here can be built. Use exactly the names printed here in the following steps—typos will break things!

### 2.2 Start the environment script

Run the environment script **once** for exactly **one** box from the list. You will automatically end up in the corresponding build sub‑directory.

```bash
. ./oe-init-build-env build/<machine>
```

As long as you stay inside the created environment within the open shell and inside the desired build sub‑directory, you do not have to run this script again and can build images or any packages via [step 2.3](#23-create-the-image).

**Note:** You can open additional shells and therefore additional build environments for other box types in parallel. Simply switch to the terminal you need; parallel builds are possible if your system is powerful enough.

### 2.3 Create the image

```bash
bitbake neutrino-image
```

This command builds the complete image with all the packages belonging to it, including packages that, depending on your configuration, are built but not installed into the image. This can take a while. Some warnings can be ignored. Errors in the setscene tasks are no problem, but any errors during build or package tasks usually abort the process.  [Please report errors or share your solution](https://forum.tuxbox-neutrino.org/forum/viewforum.php?f=77). Help is always welcome.

If everything finishes, you should see a message similar to:

```bash
"NOTE: Tasks Summary: Attempted 4568 tasks of which 4198 didn't need to be rerun and all succeeded."
```

<span style="color: green;">That's it …</span>

You will find the results under:

```bash
buildenv/poky-{DISTRO_VERSION}/build/<machine>/tmp/deploy
```

or in the public directory:

```bash
buildenv/dist/<Image-Version>/<machine>/
```

If a web server is configured that points to the public directory:

```bash
http://localhost/{DISTRO_VERSION} or, with port number, http://localhost:8080/{DISTRO_VERSION}
```

## 3. Updating

You do not need to update packages manually. BitBake does this automatically whenever a target is built, including its dependencies. If you want full control over certain package sources, you can place them in the workspace for each package, see [4.4 Packages](#44-packages). If no updates are necessary, BitBake will simply skip the builds.

### 3.1 Update an image

```bash
bitbake neutrino-image
```

### 3.2 Update a package

```bash
bitbake <package>
```

### 3.3 Update meta‑layer repositories

Running the init script with the `--update` parameter upgrades the included meta‑layers to the state of their remote repositories.

```bash
./init --update
```

If you have modified the meta‑layers, the update routines invoked by the init script should temporarily stash or rebase your uncommitted changes onto the local repository. Of course you can update your local meta‑layers (meta‑neutrino and machine layers) manually. Conflicts must always be resolved manually.

**Note:** Configuration files remain largely untouched, but variable names may be migrated. New or changed settings are not altered. Please check your configuration if necessary.

## 4. Customisation

### 4.1 Configuration

It is recommended to do the first build without modified configuration files so you get a feel for the build process and can see results quickly.
The number of possible settings is huge and not really easy to grasp for beginners. OpenEmbedded, and especially the Yocto Project, is however very well documented and is the best source of information.

#### 4.1.1 Configuration files

> \~/buildenv/poky-3.2.4/build/`<machine>`/conf/local.conf

This file resides in the build directory of each machine type and is the actual user configuration file originally intended by the build system. In this environment, however, this `local.conf` contains only a few lines and includes a global configuration. This file is **only** valid for the machine type it belongs to. Therefore you can add entries here that should apply only to that machine type. See the [schema](#14-run-the-init-script).

> \~/buildenv/local.conf.common.inc

This file contains settings that apply to all machine types and is generated on the first run of the init script from the template `~/buildenv/local.conf.common.inc.sample`.

You *could* use the build‑system‑provided `./build/<machine>/conf/local.conf` as the primary configuration file for every machine type separately, but that would increase maintenance effort. Therefore `~/buildenv/local.conf.common.inc` is just included by `./build/<machine>/conf/local.conf`.

**Note on** `~/buildenv/local.conf.common.inc.sample`**:** This is only a template and should remain untouched to avoid conflicts when updating the build‑script repository and to see what might have changed.

After an update of the build‑script repository, new or changed options may have been added or removed that are not present in the included configuration file. Keep this in mind and check and adjust your configuration if needed.

#### 4.1.2 bblayers.conf

> \~/buildenv/poky-3.2.4/build/`<machine>`/conf/bblayers.conf

This file is normally adjusted on the first run of the init script and usually needs to be changed only if you want to add, remove or replace layers.

#### 4.1.3 Reset configuration

If you want to reset your machine configurations, rename the `conf` directory (deleting is not recommended) and run the init script again.

```bash
mv ~/buildenv/poky-3.2.4/build/<machine>/conf ~/buildenv/poky-3.2.4/build/<machine>/conf.01
cd ~/buildenv
./init
```

### 4.3 Recipes

**Unless you are directly involved in developing the Poky layers, do not modify the official Poky meta‑layers! The Yocto Project explicitly advises against this, because you risk losing all your work during updates and creating incompatibilities or conflicts that are hard to maintain. The usual approach to complete, extend or override existing official recipes is the use of [.bbappend files](https://docs.yoctoproject.org/3.2.4/dev-manual/dev-manual-common-tasks.html#using-bbappend-files-in-your-layer).**

Alternatively—although also not really recommended—you could copy official recipes into your own meta‑layers and adjust them; the build system will typically prefer these copies. In that case, however, you are responsible for keeping those recipes up to date, which can unnecessarily increase maintenance effort.

The same principle applies to recipes from your own meta‑layers such as `meta-neutrino` or the machine layers. Anyone who [actively wants to work on the recipes](https://docs.yoctoproject.org/current/ref-manual/devtool-reference.html#modifying-an-existing-recipe) is of course welcome to do so.

### 4.4 Packages

If you want full control over a package’s source code—e.g. to fix something or to develop actively—you should move the source you want to work on into the workspace. See the [Neutrino example](#441-edit-source-code-in-the-workspace-example).

See [devtool](https://docs.yoctoproject.org/current/ref-manual/devtool-reference.html) and especially [devtool modify](https://docs.yoctoproject.org/current/ref-manual/devtool-reference.html#modifying-an-existing-recipe). In the workspace you are guaranteed that the build system will not touch the source code. If you ignore this, modified source code might be deleted or overwritten over and over again. Your changes could therefore be lost or become incompatible. In the default local configuration, [rm\_work](https://docs.yoctoproject.org/ref-manual/classes.html#ref-classes-rm-work) is enabled, which cleans up each package’s work directory after every successful build, so that nothing but a few logs remains.

#### 4.4.1 Edit source code in the workspace (example)

Neutrino is used as an example here, but the workflow is essentially the same for any other package.

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

You will now find the Neutrino source code under `/buildenv/poky-3.2.4/build/hd61/workspace/sources/neutrino`. You can work on it there. This means that the build system will no longer clone or automatically update the Neutrino sources from the remote Git repo on its own, but will from now on only use the local sources inside the workspace, which you maintain yourself. It is a Git repo created by devtool; you can link it to the original remote repository if that has not already been done.

If you now run:

```bash
bitbake neutrino
```

…Neutrino will from now on be built only from the local repo in the workspace:

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

**Note!** In the specific case of Neutrino it is advisable to move not only its source code but also the associated `libstb-hal` into the workspace.

```bash
devtool modify libstb-hal
```

## 5. Force a rebuild of a single package

In some cases a target may abort for whatever reason. There is no need to panic and wipe your working directory and the expensive sstate‑cache. You can perform clean‑ups for every target individually without destroying an otherwise working system.

Broken archive URLs in particular can lead to aborts. These errors are always displayed and you can check the URLs. Often it is just temporary server issues and works again after a few minutes.

To make sure that the recipe in question actually has a problem it is sensible to clean the target completely and build it again. To do this you must clean all package, build and cached data belonging to that target.

```bash
bitbake -c cleansstate <target>
```

then rebuild:

```bash
bitbake <target>
```

## 6. Force a complete image build

The init script provides the `--reset` option for this.

```bash
./init --reset
# Follow instructions
```

You can achieve the same manually by renaming the `tmp` directory in the respective build sub‑directory. You can delete it later if you want to free disk space or are sure you no longer need it:

```bash
mv tmp tmp.01
```

Then build the image again:

```bash
bitbake neutrino-image
```

If you did **not** delete the cache, the image should be built in a relatively short time. For that reason you are encouraged to keep the cache. The directory where the cache is located is controlled by the variable `${SSTATE_DIR}` and can be changed in the configuration.

This directory is quite valuable and it is rarely necessary to delete it. Please bear in mind that the build process will take significantly longer after deleting the cache.

## 7. Licence

```
MIT License
```

## 8. Further information

More information on the Yocto build system:

* [https://docs.yoctoproject.org](https://docs.yoctoproject.org)
