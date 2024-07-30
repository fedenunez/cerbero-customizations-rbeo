# Packages for RBEO

Welcome to the RBEO customizations repository! This repo contains the tweaks needed to build the open-source libraries for RBEO APP, using the Cerbero build system. With Cerbero, you can create libraries for both iOS and Android using a single, unified build system.

Cerbero is a powerful and friendly build system used by the GStreamer community to compile their libraries for multiple platforms. It's an excellent choice for bundling open-source dependencies for mobile applications.

In this repository, we define the missing recipes in Cerbero for our target application and package all the libraries together.

The result of the build system is a distributable tar.gz or iOS Framework that you can easily add to your mobile project.

In order to use the library on IOS you will need to:
- add the created Framework into Link Binary With Libraries (Project settings -> Build Phases)
- add 

## Building

Just run `make [android/ios]`, this will fetch Cerbero and install our extensions.

You can edit the CERBERO version in the Makefile.

If you change the target platform (android/ios), please run `make clean` before trying to build again.

## Extending or repurposing this

Just add the recipes or packages that you want in the correct folder, edit the Makefile to point to your package, and run it.

This Makefile will install anything that you place in the recipe or package folder in the appropriate cerbero-$version folder, as a link to the original recipe. Then you can jump into that folder and manually run Cerbero to fine-tune your recipe or package as:

```
./cerbero-uninstalled -c config/cross-ios-universal.cbc build myLovelyRecipe
```
or
```
./cerbero-uninstalled -c config/cross-ios-universal.cbc package myLovelyPackage
```

