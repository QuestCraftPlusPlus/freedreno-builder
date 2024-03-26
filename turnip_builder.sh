#!/bin/bash -e
green='\033[0;32m'
red='\033[0;31m'
nocolor='\033[0m'
deps="meson ninja patchelf unzip curl pip flex bison zip"
workdir="$(pwd)/turnip_workdir"
magiskdir="$workdir/turnip_module"
ndkver="android-ndk-r26"
clear



echo "Checking system for required Dependencies ..."
for deps_chk in $deps;
	do
		sleep 0.25
		if command -v "$deps_chk" >/dev/null 2>&1 ; then
			echo -e "$green - $deps_chk found $nocolor"
		else
			echo -e "$red - $deps_chk not found, can't countinue. $nocolor"
			deps_missing=1
		fi;
	done

	if [ "$deps_missing" == "1" ]
		then echo "Please install missing dependencies" && exit 1
	fi



echo "Installing python Mako dependency (if missing) ..." $'\n'
pip install mako &> /dev/null



echo "Creating and entering to work directory ..." $'\n'
mkdir -p "$workdir" && cd "$_"



echo "Downloading android-ndk from google server (~506 MB) ..." $'\n'
curl https://dl.google.com/android/repository/"$ndkver"-linux.zip --output "$ndkver"-linux.zip &> /dev/null
###
echo "Exracting android-ndk to a folder ..." $'\n'
unzip "$ndkver"-linux.zip  &> /dev/null



echo "Downloading mesa source (~30 MB) ..." $'\n'
curl https://codeload.github.com/QuestCraftPlusPlus/mesa/zip/refs/heads/LTS-Freedreno --output mesa-LTS.zip &> /dev/null
###
echo "Exracting mesa source to a folder ..." $'\n'
unzip mesa-LTS.zip &> /dev/null
cd mesa-LTS-Freedreno



echo "Creating meson cross file ..." $'\n'
ndk="$workdir/$ndkver/toolchains/llvm/prebuilt/linux-x86_64/bin"
cat <<EOF >"android-aarch64"
[binaries]
ar = '$ndk/llvm-ar'
c = ['ccache', '$ndk/aarch64-linux-android26-clang', '-O3', '-DVK_USE_PLATFORM_ANDROID_KHR', '-fPIC']
cpp = ['ccache', '$ndk/aarch64-linux-android26-clang++', '-O3', '-DVK_USE_PLATFORM_ANDROID_KHR', '-fPIC', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '-static-libstdc++']
c_ld = 'lld'
cpp_ld = 'lld'
strip = '$ndk/aarch64-linux-android26-strip'
pkgconfig = ['env', 'PKG_CONFIG_LIBDIR=NDKDIR/pkgconfig', '/usr/bin/pkg-config']
[host_machine]
system = 'android'
cpu_family = 'arm'
cpu = 'armv8'
endian = 'little'
EOF



echo "Generating build files ..." $'\n'
meson "build-quest-release" --prefix=/tmp/mesa --cross-file "$workdir"/mesa-LTS/android-aarch64 --buildtype release -Dplatforms=android -Dplatform-sdk-version=32 -Dandroid-stub=true -Dllvm=disabled -Dvulkan-drivers=freedreno -Dfreedreno-kmds=kgsl -Dgallium-drivers=

echo "Patching LibArchive build files ..." $'\n'
curl https://raw.githubusercontent.com/QuestCraftPlusPlus/freedreno-builder/main/libarchive-meson.build --output "$workdir"/mesa-LTS/subprojects/libarchive-3.7.2/meson.build

echo "Compiling build files ..." $'\n'
ninja -C build-quest-release 



echo "Using patchelf to match soname ..."  $'\n'
cp "$workdir"/mesa-LTS/build-quest-release/src/freedreno/vulkan/libvulkan_freedreno.so "$workdir"
cd "$workdir"


if ! [ -a libvulkan_freedreno.so ]; then
	echo -e "$red Build failed! $nocolor" && exit 1
fi



echo "Prepare magisk module structure ..." $'\n'
mkdir -p "$magiskdir" 


echo "Copy necessary files from work directory ..." $'\n'
cp "$workdir"/libvulkan_freedreno.so "$magiskdir"/
cd "$magiskdir"

echo "Packing files in to magisk module ..." $'\n'
zip -r "$workdir"/turnip.zip ./* &> /dev/null
if ! [ -a "$workdir"/turnip.zip ];
	then echo -e "$red-Packing failed!$nocolor" && exit 1
	else echo -e "$green-All done, you can take your module from here;$nocolor" && echo "$workdir"/turnip.zip
fi
