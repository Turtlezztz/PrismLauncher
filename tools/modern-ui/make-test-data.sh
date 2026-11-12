#!/bin/bash
# Creates a throwaway launcher data dir with a few fake instances for UI testing.
# usage: make-test-data.sh <dir>
D=${1:?dir}
mkdir -p "$D/instances"
printf "Language=en_US\nIgnoreJavaWizard=true\nAutomaticJavaDownload=true\nAutomaticJavaSwitch=true\nUserAskedAboutAutomaticJavaDownload=true\nApplicationTheme=dark\nIconTheme=flat_white\n" > "$D/prismlauncher.cfg"
for n in "Vanilla 1.21:1.21.4::grass" "Fabric Survival:1.21.1:net.fabricmc.fabric-loader=0.16.9:fabric" "All The Mods 10:1.21.1:net.neoforged=21.1.80:flame" "Skyblock:1.20.1:net.minecraftforge=47.3.0:skeleton" "Creative Builds:1.20.4::brick"; do
  IFS=: read name mc loader icon <<< "$n"; dir="$D/instances/$name"; mkdir -p "$dir/minecraft/mods" "$dir/minecraft/saves" "$dir/minecraft/screenshots"
  printf "InstanceType=OneSix\nname=%s\niconKey=%s\nlastLaunchTime=%s\ntotalTimePlayed=%s\n" "$name" "$icon" "$(( ($(date +%s) - RANDOM*30) * 1000 ))" "$((RANDOM*5))" > "$dir/instance.cfg"
  comps="{\"uid\":\"net.minecraft\",\"version\":\"$mc\",\"important\":true}"
  [ -n "$loader" ] && comps="$comps,{\"uid\":\"${loader%%=*}\",\"version\":\"${loader##*=}\"}"
  echo "{\"formatVersion\":1,\"components\":[$comps]}" > "$dir/mmc-pack.json"
done
echo '{"formatVersion":1,"groups":{"Modded":{"hidden":false,"instances":["Fabric Survival","All The Mods 10","Skyblock"]}}}' > "$D/instances/instgroups.json"
echo "test data in $D"
