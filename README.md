## Checkout
Submodules must be checked out to build SG Physics.
```
git submodule update --init --recursive
```

## Compiling SG Physics

Before working on this project, the SG physicd gd extension must be compiled.
SCons and a C++ compiler is required.
To install scons, run:
```
python -m pip install scons
```
Next, build the gdextension.
```
cd sg-physics-2d
scons target=template_debug
```

## Player Controls

Arrow Keys - Move up, left and right
Z - Kick
Down Arrow while in air - Fast Fall (gravity scale is set to 7)
X - Use Super. Supers are different for each character.
C - Switch Character. Each player has two characters they can switch between.

Hitting the ball adds charge to the super meter.
