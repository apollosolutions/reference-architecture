#!/bin/bash

# Navigate to the subgraphs folder
cd subgraphs || { echo "Subgraphs folder not found"; exit 1; }

# Loop through all subfolders
for dir in */; do
    if [ -d "$dir" ]; then
        # Check if the directory contains a package.json file
        if [ ! -f "$dir/package.json" ]; then
            echo "No package.json found in $dir, skipping."
            continue
        fi

        echo "Processing $dir"
        cd "$dir" || continue
        # Run npm install with the specified flags
        npm i --package-lock-only --workspaces=false
        volta pin node@22
        cd ..
    fi
done

echo "Done processing all subgraphs, now processing client."

# Navigate to the client folder
cd ../client || { echo "Client folder not found"; exit 1; }
npm i --package-lock-only --workspaces=false
volta pin node@22

echo "Done processing client."

# Navigate to the coprocessor folder
cd ../coprocessor || { echo "Coprocessor folder not found"; exit 1; }
npm i --package-lock-only --workspaces=false
volta pin node@22

echo "Done processing coprocessor."