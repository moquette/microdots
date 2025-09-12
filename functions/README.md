# Functions Microdot

## Purpose
Provides global shell functions available across all terminal sessions.

## What's Included
- **c** - Quick navigation function for code projects
- **mkd** - Create and enter a directory in one command
- **extract** - Universal archive extraction

## Usage
Functions are automatically loaded into your shell environment. Simply call them by name:
```bash
c myproject  # Navigate to ~/Code/myproject
mkd newfolder  # Create and cd into newfolder
extract file.tar.gz  # Extract any archive type
```

## Note
These functions are loaded early in the shell initialization to be available to all other microdots.