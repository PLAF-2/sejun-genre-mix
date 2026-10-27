import bpy

print("BLENDER_VERSION", bpy.app.version_string)
print("MPFB_ENABLED", any("mpfb" in key.lower() for key in bpy.context.preferences.addons.keys()))
print("MPFB_OPERATORS")
for name in sorted(dir(bpy.ops.mpfb)):
    if not name.startswith("_"):
        print(name)

for op_name in ["create_human", "add_standard_rig", "load_library_skin", "load_target"]:
    op = getattr(bpy.ops.mpfb, op_name)
    print("OPERATOR", op_name)
    try:
        for prop in op.get_rna_type().properties:
            print("  ", prop.identifier, prop.type, getattr(prop, "default", None))
    except Exception as exc:
        print("  ERROR", exc)
