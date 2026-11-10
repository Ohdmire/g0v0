#!/bin/sh

# Run this script to use a local copy of g0v0-framework rather than fetching it from nuget.
# It expects the g0v0-framework directory to be at the same level as this repository.
#
# https://github.com/ppy/osu-framework/wiki/Testing-local-framework-checkout-with-other-projects

GAME_CSPROJ="osu.Game/osu.Game.csproj"
ANDROID_PROPS="osu.Android.props"
IOS_PROPS="osu.iOS.props"
SLN="osu.sln"
FW="../g0v0-framework"

# `dotnet remove package` rejects .props files. `dotnet remove reference` drops the
# PackageReference on both csproj and props, and is a no-op (non-zero) when it is absent.
remove_ref() {
    dotnet remove "$1" reference "$2" || true
}

remove_ref "$GAME_CSPROJ" g0v0.Framework
remove_ref "$GAME_CSPROJ" ppy.osu.Framework
remove_ref "$ANDROID_PROPS" g0v0.Framework.Android
remove_ref "$ANDROID_PROPS" ppy.osu.Framework.Android
remove_ref "$IOS_PROPS" g0v0.Framework.iOS
remove_ref "$IOS_PROPS" ppy.osu.Framework.iOS

dotnet sln "$SLN" add \
    "$FW/osu.Framework/osu.Framework.csproj" \
    "$FW/osu.Framework.NativeLibs/osu.Framework.NativeLibs.csproj" \
    "$FW/osu.Framework.Android/osu.Framework.Android.csproj" \
    "$FW/osu.Framework.iOS/osu.Framework.iOS.csproj"

grep -Fq 'osu.Framework.csproj' "$GAME_CSPROJ" || \
    dotnet add "$GAME_CSPROJ" reference "$FW/osu.Framework/osu.Framework.csproj"
grep -Fq 'osu.Framework.Android.csproj' "$ANDROID_PROPS" || \
    dotnet add "$ANDROID_PROPS" reference "$FW/osu.Framework.Android/osu.Framework.Android.csproj"
grep -Fq 'osu.Framework.iOS.csproj' "$IOS_PROPS" || \
    dotnet add "$IOS_PROPS" reference "$FW/osu.Framework.iOS/osu.Framework.iOS.csproj"

# workaround for dotnet add not inserting $(MSBuildThisFileDirectory) on props files
# dotnet add writes backslashes and omits $(MSBuildThisFileDirectory) on props files.
for props in ./osu.Android.props ./osu.iOS.props; do
    sed -i.bak -E '/ProjectReference Include/ s:\\:/:g; /ProjectReference Include/ s:"(\.\./)+g0v0-framework:"$(MSBuildThisFileDirectory)../g0v0-framework:' "$props" && rm "$props.bak"
done

# needed because iOS framework nupkg includes a set of properties to work around certain issues during building,
# and those get ignored when referencing framework via project, therefore we have to manually include it via props reference.
if ! grep -Fq 'osu.Framework.iOS.props' ./osu.iOS.props; then
    sed -i.bak '/<\/Project>/i\
  <Import Project="$(MSBuildThisFileDirectory)../g0v0-framework/osu.Framework.iOS.props"/>\
' ./osu.iOS.props && rm osu.iOS.props.bak
fi

tmp=$(mktemp)

jq '.solution.projects += ["../g0v0-framework/osu.Framework/osu.Framework.csproj", "../g0v0-framework/osu.Framework.NativeLibs/osu.Framework.NativeLibs.csproj"] | .solution.projects |= unique' osu.Desktop.slnf > "$tmp"
mv -f "$tmp" osu.Desktop.slnf

jq '.solution.projects += ["../g0v0-framework/osu.Framework/osu.Framework.csproj", "../g0v0-framework/osu.Framework.NativeLibs/osu.Framework.NativeLibs.csproj", "../g0v0-framework/osu.Framework.Android/osu.Framework.Android.csproj"] | .solution.projects |= unique' osu.Android.slnf > "$tmp"
mv -f "$tmp" osu.Android.slnf

jq '.solution.projects += ["../g0v0-framework/osu.Framework/osu.Framework.csproj", "../g0v0-framework/osu.Framework.NativeLibs/osu.Framework.NativeLibs.csproj", "../g0v0-framework/osu.Framework.iOS/osu.Framework.iOS.csproj"] | .solution.projects |= unique' osu.iOS.slnf > "$tmp"
mv -f "$tmp" osu.iOS.slnf
