package com.adilhanney.saber

import androidx.core.content.FileProvider

/// Hands the camera app the file a photo is to be written to. A class of
/// its own so that it can't clash with the file providers of plugins.
class CameraFileProvider : FileProvider()
