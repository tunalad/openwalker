#!/bin/bash
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
ADDONS="$(cd "$ROOT/../addons" && pwd)"
GODOT_LIB="$ROOT/godot-lib.aar"
SDK_JAR="$HOME/android-sdk/platforms/android-36/android.jar"
TEMPLATES="$ROOT/templates"

build() {
	local name="$1"
	local out="$ADDONS/$name"
	local tmp="/tmp/aabuild-$name"

	local java_files=("$ROOT/$name"/*.java)
	[ ${#java_files[@]} -gt 0 ] && [ -f "${java_files[0]}" ] || {
		echo "no .java files in $ROOT/$name/"
		exit 1
	}
	[ -f "$GODOT_LIB" ] || {
		echo "missing godot-lib.aar"
		exit 1
	}
	[ -f "$SDK_JAR" ] || {
		echo "missing android.jar at $SDK_JAR"
		exit 1
	}

	echo "building $name..."

	mkdir -p "$tmp/classes" "$tmp/godot"
	unzip -qo "$GODOT_LIB" "classes.jar" -d "$tmp/godot"

	javac -source 17 -target 17 \
		-cp "$SDK_JAR:$tmp/godot/classes.jar" \
		-d "$tmp/classes" "$ROOT/$name"/*.java

	cd "$tmp/classes" && jar cf "$tmp/classes.jar" .

	# AAR requires R.txt (even if empty) and aar-metadata.properties
	touch "$tmp/R.txt"
	mkdir -p "$tmp/META-INF/com/android/build/gradle"
	cat >"$tmp/META-INF/com/android/build/gradle/aar-metadata.properties" <<EOF
aarFormatVersion=1.0
aarMetadataVersion=1.0
minCompileSdk=26
minCompileSdkExtension=0
minAndroidGradlePluginVersion=1.0.0
coreLibraryDesugaringEnabled=false
EOF

	mkdir -p "$out/bin"
	cp "$ROOT/$name/AndroidManifest.xml" "$tmp/AndroidManifest.xml"
	cd "$tmp" && jar cf "$out/bin/$name.aar" \
		AndroidManifest.xml classes.jar R.txt \
		META-INF/com/android/build/gradle/aar-metadata.properties

	for f in plugin.cfg export_plugin.gd; do
		[ -f "$out/$f" ] && echo "$f exists, skipping" || {
			sed "s/{{NAME}}/$name/g; s/{{AUTHOR}}/$(whoami)/g" "$TEMPLATES/$f" >"$out/$f"
			echo "created $f"
		}
	done

	rm -rf "$tmp"
	echo "made $out/bin/$name.aar"
}

[ $# -eq 0 ] && {
	echo "Usage: $0 <PluginDir>"
	echo "       $0 all"
	exit 1
}

if [ "$1" = "all" ]; then
	for dir in "$ROOT"/*/; do
		name=$(basename "$dir")
		[ -f "$dir/$name.java" ] && build "$name"
	done
else
	build "$1"
fi
