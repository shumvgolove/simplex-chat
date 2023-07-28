package chat.simplex.common.platform

import androidx.compose.runtime.*
import chat.simplex.common.*
import chat.simplex.common.views.helpers.generalGetString
import chat.simplex.res.MR
import java.io.*
import java.net.URI

actual val dataDir: File = File(desktopPlatform.dataPath)
actual val tmpDir: File = File(System.getProperty("java.io.tmpdir") + File.separator + "simplex").also { it.deleteOnExit() }
actual val filesDir: File = File(dataDir.absolutePath + File.separator + "simplex_v1_files")
actual val appFilesDir: File = filesDir
actual val coreTmpDir: File = File(dataDir.absolutePath + File.separator + "tmp")
actual val dbAbsolutePrefixPath: String = dataDir.absolutePath + File.separator + "simplex_v1"

actual val chatDatabaseFileName: String = "simplex_v1_chat.db"
actual val agentDatabaseFileName: String = "simplex_v1_agent.db"

actual val databaseExportDir: File = tmpDir

@Composable
actual fun rememberFileChooserLauncher(getContent: Boolean, onResult: (URI?) -> Unit): FileChooserLauncher =
  remember { FileChooserLauncher(getContent, onResult) }

@Composable
actual fun rememberFileChooserMultipleLauncher(onResult: (List<URI>) -> Unit): FileChooserMultipleLauncher =
  remember { FileChooserMultipleLauncher(onResult) }

actual class FileChooserLauncher actual constructor() {
  var getContent: Boolean = false
  lateinit var onResult: (URI?) -> Unit

  constructor(getContent: Boolean, onResult: (URI?) -> Unit): this() {
    this.getContent = getContent
    this.onResult = onResult
  }

  actual suspend fun launch(input: String) {
    val res = if (getContent) {
      val params = DialogParams(
        allowMultiple = false,
        fileFilter = fileFilter(input),
        fileFilterDescription = fileFilterDescription(input),
      )
      simplexWindowState.openDialog.awaitResult(params)
    } else {
      simplexWindowState.saveDialog.awaitResult()
    }
    onResult(res?.toURI())
  }
}

actual class FileChooserMultipleLauncher actual constructor() {
  lateinit var onResult: (List<URI>) -> Unit

  constructor(onResult: (List<URI>) -> Unit): this() {
    this.onResult = onResult
  }

  actual suspend fun launch(input: String) {
    val params = DialogParams(
        allowMultiple = true,
        fileFilter = fileFilter(input),
        fileFilterDescription = fileFilterDescription(input),
      )
    onResult(simplexWindowState.openMultipleDialog.awaitResult(params).map { it.toURI() })
  }
}

private fun fileFilter(input: String): (File?) -> Boolean = when(input) {
  "image/*" -> { file -> if (file?.isDirectory == true) true else if (file != null) isImage(file.toURI()) else false }
  "video/*" -> { file -> if (file?.isDirectory == true) true else if (file != null) isVideo(file.toURI()) else false }
  "*/*" -> { _ -> true }
  else -> { _ -> true }
}

private fun fileFilterDescription(input: String): String = when(input) {
  "image/*" -> generalGetString(MR.strings.gallery_image_button)
  "video/*" -> generalGetString(MR.strings.gallery_video_button)
  "*/*" -> generalGetString(MR.strings.choose_file)
  else -> ""
}

actual fun URI.inputStream(): InputStream? = File(URI("file:" + toString().removePrefix("file:"))).inputStream()
actual fun URI.outputStream(): OutputStream = File(URI("file:" + toString().removePrefix("file:"))).outputStream()