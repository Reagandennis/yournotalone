package com.techgetafrica.yournotalone

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle

/**
 * Opened by Health Connect when someone taps the privacy link on its
 * permission screen, and by Android 14+'s permission pages: shows the
 * privacy policy's section on health data, then gets out of the way.
 *
 * Google requires an app asking for Health Connect permissions to show why
 * from here. Keep the address in step with the policy the store listings
 * link to (docs/store/app_store_listing.md).
 */
class HealthPermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            startActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse(POLICY_URL))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (e: Exception) {
            // No browser at all: nothing more this screen can do.
        }
        finish()
    }

    private companion object {
        const val POLICY_URL = "https://yournotalone.techgetafrica.com/privacy-policy#health"
    }
}
