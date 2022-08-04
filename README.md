# <img src="https://user-images.githubusercontent.com/3391295/95904392-bd2d0880-0d97-11eb-9ba8-c4e1b55dcc39.png" alt="action" height="30">


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
        workdir: ./backend
```
