#!/bin/bash
# Author: Yoshi Jaeger, Copyright 2020
# Description: Parse Strings.swift and add those to their respective language localization files.

if [[ -z "$1" ]]; then
	echo "First argument (path of Strings.swift) not specified"
	exit 1
fi

if [[ -z "$2" ]]; then
	echo "Second argument (path of lproj directories) not specified"
	exit 1
fi

outputDir="output"
lproj_path="$2"
lcount=0
path="$1"
ln=0
g=0

add_to_single_file=1

declare -a localeStr

function copy_lang_files {
	find "$outputDir" -type f -mindepth 1 -name Localizable\.strings\.\* -exec rm -- {} \;
	mkdir -p "$outputDir"
	find "$lproj_path" -not -path \.\*Base\.\*lproj -mindepth 1 -type d -exec cp -R -- {} "./$outputDir" \;
}

function convertToLE16 {
	find "$outputDir" -type f -name Localizable\.strings\.append | while read line; do
		#iconv -f UTF-8 -t UTF-16 "$line" > "$line.new"
		iconv -f ASCII -t UTF-8 "$line" > "$line.new"
	done
}


function clean {
	find "$outputDir" -type f -mindepth 1 -name Localizable\.strings\.append -exec rm -- {} \;
	find "$outputDir" -type f -mindepth 1 -name Localizable\.strings\.conv -exec rm -- {} \;
}

function add_localized_string {
	# Localized ID
	idStr="$1"

	# enum property
	name="$2" 

	# Localization Value (English)
	value="$3"

	# Comment that describes the localization
	comment="$4"

	added=0

	for f in "$outputDir"/*; do
		if [[ "$f" = "$outputDir/Localizable.strings.append" ]]
		then
			continue
		fi

		file="$f/Localizable.strings"
		newFile="${file}.append"
		tempFile="$file.conv"

		if [[ ! -f "$tempFile" ]]; then
			iconv -f UTF-16 -t UTF-8 "$file" > "$tempFile"
		fi

		grep "\"$idStr\"" "$tempFile" > /dev/null
		rc=$?

		if [[ $rc -ne 0 ]]; then
			# not found
			if [[ $added -eq 0 ]]; then
				echo "Adding $idStr..."
				added=1
			fi

			if [[ add_to_single_file -eq 0 ]]; then
				echo "" >> "$newFile"
				echo "/* $comment */" >> "$newFile"
				echo "\"$idStr\" = \"$value\";" >> "$newFile"
			else 
				# Break and add the string immediately
				break
			fi
		fi
	done

	if [[ $added -gt 0 ]]; then
		lcount=$(($lcount + 1))

		if [[ add_to_single_file -eq 1 ]]; then
			outputFile="$outputDir/Localizable.strings.append"
			echo "" >> "$outputFile"
			echo "/* $comment */" >> "$outputFile"
			echo "\"$idStr\" = \"$value\";" >> "$outputFile"
		fi
	fi
}

function join_by { local IFS="$1"; shift; echo "$*"; }

# MAIN

set -e
echo "Copying existing Translations to output directory $outputDir..."
copy_lang_files
set +e

echo "Analyzing $path and adding Translations..."
while read line; do
	ln=$(($ln + 1))
	joined=$(IFS=. ; echo "${localeStr[*]}")

	if [[ "$line" =~ (enum[ ]+([^ ]+)) ]]; then
		match="${BASH_REMATCH[2]}"
		if [[ "$match" = "S" ]]; then
			# S will not open a new group
			:
		else
			g=$(($g + 1))
			localeStr=( "${localeStr[@]}" "$match" )
		fi
	fi

	if [[ "$line" =~ NSLocalizedString ]]; then
		if [[ ! "$line" =~ (static let ([^ ]+)) ]]; then
			echo "Error -1 at line $ln"
			exit -1
		fi

		name="${BASH_REMATCH[2]}"

		if [[ ! "$line" =~ NSLocalizedString..([^\"]+) ]]; then
			echo "Error 1 at line $ln"
			exit 1
		fi

		idStr="${BASH_REMATCH[1]}"

		if [[ ! "$line" =~ value\:[\ ]?\"([^\"]+) ]]; then
			echo "Error 2 at line $ln"
			exit 2
		fi

		value="${BASH_REMATCH[1]}"				

		if [[ ! "$line" =~ comment\:[\ ]?\"([^\"]+) ]]; then
			echo "Error 3 at line $ln"
			exit 3
		fi

		comment="${BASH_REMATCH[1]}"		

		# Valid! Call another script for every!! language
		# that adds the string to the Localized file,
		# and its existing translation.
		add_localized_string "$idStr" "$name" "$value" "$comment"
	fi

	if [[ "$line" =~ [}] ]]; then
		if [[ $g -gt 0 ]]; then
			unset 'localeStr[ ${#localeStr[@]} - 1 ]'
			g=$(($g - 1))
		fi
	fi
done < $path;

echo "$lcount Localizations were missing. Added them to the Language files in $outputDir"

echo "Converting ASCII to UTF-16 LE ..."
convertToLE16

echo "Cleaning directories..."
clean