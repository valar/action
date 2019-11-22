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
    - uses: valar/action@v0
      
    - name: valar push
      run: |
        valar --api-token ${{ secrets.VALAR_TOKEN }} --api-endpoint https://api.valar.dev push
```
