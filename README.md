# Squared (Squared Pics)
Squared, or Squared Pics as it is known in the App Store, is an iOS app for squaring rectangular images without cropping or scaling. It does this by running a seam carving type of algorithm; the algorithm was adjusted (quality reduced) so that it can work on an iPhone in as close to real-time as possible. The algorithm works as follows:

- An image is loaded by the user
- The image is resized so that its largest dimension is no larger than 1000 pixles
  - For best results the original image would be used, but that increases run-time
  - The limit is presently hard defined, but it should be device dependent
- Faces are detected in the image using Apple provided frameworks
- Edges are detected in the image (the image's "energies") using a Sobel filter
- The energies under faces are increased to decrease the likelyhood of them being changed
- A seam matrix is created to determine the paths of least resistance
- Seams are itteretively removed from the image
  - The seams of lowest value are discoverd
  - If there is a tie for the lowest value, then one is randomly choosen to prevent a clustering of seam cuts
- At a defined interval the seam matrix is recalculated
  - For best results this would be done after every seam is removed, but that increases run-time
  - The interval is presently hard defined (via #define), but it should be device dependent
- The resulting image is displayed

## Squared App
The App is a very simple single-view application which allows people to open an image, process it, and then save or share it (using the sharing action sheet).

## Squared Image Editing Extension
The image editing extension is launched from within the standard Photos app via its editing section. It performs the same functions as the app (they both call the same code: the SeamCarvingBridge class calls the SeamCarving C files), but rather than using the share sheet it saves changes back to the phtos app.
