# Publish GitHub Action

This action lets you push your code to valar.

# Example Workflow

```
name: "Publish to Valar"
on:
  push:
    branches:    
      - master

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v1
    - uses: valar/action@v1
      with:
        valar_token: ${{ secrets.VALAR_TOKEN }}
```
