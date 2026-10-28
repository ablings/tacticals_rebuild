import bpy
for im in bpy.data.images: print("IMG", im.name, repr(im.filepath), im.size[:])
