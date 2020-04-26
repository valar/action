# Valar Build Action

This action lets you push your code to Valar.

## Example workflow

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
        token: ${{ secrets.VALAR_TOKEN }}
```
