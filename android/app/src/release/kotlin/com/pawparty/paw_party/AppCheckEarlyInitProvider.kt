package com.pawparty.paw_party

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri

/**
 * Release: no-op. App Check uses Play Integrity from Dart ([firebase_bootstrap]).
 * The debug [ContentProvider] lives only under `src/debug/` so release AABs never
 * load [firebase-appcheck-debug] classes (avoids startup crashes from missing/stripped debug types).
 */
class AppCheckEarlyInitProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun getType(uri: Uri): String? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0
}
