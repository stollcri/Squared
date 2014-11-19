# Squared (Squared Pics)
Squared, or Squared Pics as it is known in the App Store, is an iOS app for squaring rectangular images without cropping or scaling. It does this by running a seam carving type of algorithm.

## Squared App
The App is a very simple single-view application which allows people to open an image, process it, and then save or share it (using the sharing action sheet).

## Square Image Editing Extension
The image editing extension is launched from within the standard Photos app via its editing section. It performs the same functions as the app (they both call the same code: the SeamCarvingBridge class calls the SeamCarving C files), but rather than using the share sheet it saves changes back to the phtos app.
