#!/bin/sh

FILE="./frameworks/base/packages/SystemUI/src/com/android/systemui/shade/NotificationShadeWindowControllerImpl.java"

if [ ! -f "$FILE" ]; then
    echo "File not found: $FILE"
    exit 1
fi

echo "Patching $FILE ..."

# 1. Add import if missing
if ! grep -q "android.content.ContentResolver" "$FILE"; then
    sed -i '/import android.util.Log;/a import android.content.ContentResolver;' "$FILE"
    echo "Import added."
else
    echo "Import already exists, skipping."
fi

# 2. Insert ContentResolver block after apply(mCurrentState); if not present
if ! grep -q "Settings.System.putInt(cr, \"qs.fps.expanded\"" "$FILE"; then
    awk '
    /if \(mCurrentState.shadeOrQsExpanded != isExpanded\) {/{f=1} 
    f && /apply\(mCurrentState\);/{
        print
        print ""
        print "            ContentResolver cr = mContext.getContentResolver();"
        print ""
        print "            if (isExpanded) {"
        print "                Log.d(TAG, \"Shade expand detected\");"
        print "                try {"
        print "                    Settings.System.putInt(cr, \"qs.fps.expanded\", 1);"
        print "                } catch (Exception e) {"
        print "                    Log.e(TAG, \"Failed to update settings\", e);"
        print "                }"
        print "            } else {"
        print "                Log.d(TAG, \"Shade collapsed\");"
        print "                try {"
        print "                    Settings.System.putInt(cr, \"qs.fps.expanded\", 0);"
        print "                } catch (Exception e) {"
        print "                    Log.e(TAG, \"Failed to update settings\", e);"
        print "                }"
        print "            }"
        f=0
        next
    }
    {print}
    ' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
    echo "ContentResolver block added."
else
    echo "ContentResolver block already exists, skipping."
fi

echo "Patch applied (idempotent)!"