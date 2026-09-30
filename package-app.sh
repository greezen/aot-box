#!/usr/bin/env bash
set -euo pipefail

# Wrap ./aotbox-gui in a real .app so Finder launches it as a GUI app.
# Double-clicking the raw binary opens Terminal; double-clicking the .app does not.

HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="${HERE}/aotbox-gui"
APP="${HERE}/Aotbox.app"

if [[ ! -x "${BIN}" ]]; then
    echo "missing ${BIN}; run ./build.sh first" >&2
    exit 1
fi

rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BIN}" "${APP}/Contents/MacOS/aotbox-gui"
chmod +x "${APP}/Contents/MacOS/aotbox-gui"

# Same mark as make_app_icon() in macos_bridge.mm, drawn at 1024 so Finder
# can scale a sharp icns. The running app still paints the Dock icon itself.
ICON_SRC="$(mktemp -d)"
cat > "${ICON_SRC}/icon.m" << 'EOF'
#import <AppKit/AppKit.h>

static NSImage *draw_icon(void) {
    const NSSize canvas = NSMakeSize(1024, 1024);
    return [NSImage imageWithSize:canvas flipped:NO drawingHandler:^BOOL(NSRect rect) {
        const CGFloat pad = 36;
        NSRect box = NSInsetRect(rect, pad, pad);
        const CGFloat radius = box.size.width * 0.225;
        NSBezierPath *shell = [NSBezierPath bezierPathWithRoundedRect:box xRadius:radius yRadius:radius];
        NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithSRGBRed:0.18 green:0.45 blue:0.78 alpha:1]
                                                              endingColor:[NSColor colorWithSRGBRed:0.06 green:0.16 blue:0.34 alpha:1]];
        [gradient drawInBezierPath:shell angle:-90];
        [NSGraphicsContext saveGraphicsState];
        [shell addClip];
        [[NSColor colorWithSRGBRed:0.98 green:0.66 blue:0.12 alpha:1] setFill];
        NSRectFill(NSMakeRect(NSMinX(box), NSMinY(box), box.size.width, box.size.height * 0.145));
        [NSGraphicsContext restoreGraphicsState];
        NSFont *font = [NSFont monospacedSystemFontOfSize:300 weight:NSFontWeightBold];
        NSDictionary *attrs = @{
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: NSColor.whiteColor
        };
        NSString *mark = @"{ }";
        NSSize textSize = [mark sizeWithAttributes:attrs];
        [mark drawAtPoint:NSMakePoint(NSMidX(box) - textSize.width / 2.0,
                                      NSMidY(box) - textSize.height / 2.0 + 36)
            withAttributes:attrs];
        return YES;
    }];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        if (argc < 2) {
            return 1;
        }
        NSString *pngPath = [NSString stringWithUTF8String:argv[1]];
        if (argc == 2) {
            NSImage *image = draw_icon();
            CGImageRef cg = [image CGImageForProposedRect:NULL context:nil hints:nil];
            NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cg];
            NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            [png writeToFile:pngPath atomically:YES];
            return 0;
        }
        NSImage *icon = [[NSImage alloc] initWithContentsOfFile:pngPath];
        NSString *appPath = [NSString stringWithUTF8String:argv[2]];
        BOOL ok = [[NSWorkspace sharedWorkspace] setIcon:icon forFile:appPath options:0];
        return ok ? 0 : 1;
    }
}
EOF
clang -fobjc-arc -framework AppKit "${ICON_SRC}/icon.m" -o "${ICON_SRC}/icon"
"${ICON_SRC}/icon" "${ICON_SRC}/icon-1024.png"

ICONSET="${ICON_SRC}/AppIcon.iconset"
mkdir -p "${ICONSET}"
for size in 16 32 64 128 256 512 1024; do
    sips -z "${size}" "${size}" "${ICON_SRC}/icon-1024.png" --out "${ICONSET}/_${size}.png" >/dev/null
done
cp "${ICONSET}/_16.png"   "${ICONSET}/icon_16x16.png"
cp "${ICONSET}/_32.png"   "${ICONSET}/icon_16x16@2x.png"
cp "${ICONSET}/_32.png"   "${ICONSET}/icon_32x32.png"
cp "${ICONSET}/_64.png"   "${ICONSET}/icon_32x32@2x.png"
cp "${ICONSET}/_128.png"  "${ICONSET}/icon_128x128.png"
cp "${ICONSET}/_256.png"  "${ICONSET}/icon_128x128@2x.png"
cp "${ICONSET}/_256.png"  "${ICONSET}/icon_256x256.png"
cp "${ICONSET}/_512.png"  "${ICONSET}/icon_256x256@2x.png"
cp "${ICONSET}/_512.png"  "${ICONSET}/icon_512x512.png"
cp "${ICONSET}/_1024.png" "${ICONSET}/icon_512x512@2x.png"
iconutil -c icns "${ICONSET}" -o "${APP}/Contents/Resources/AppIcon.icns"

cat > "${APP}/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>aotbox-gui</string>
    <key>CFBundleIdentifier</key>
    <string>app.aotbox</string>
    <key>CFBundleName</key>
    <string>Aotbox</string>
    <key>CFBundleDisplayName</key>
    <string>Aotbox</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Seal Info.plist and AppIcon.icns first. codesign rejects a custom Finder
# icon, so the file icon is applied after the signature.
codesign --force --sign - "${APP}"
"${ICON_SRC}/icon" "${ICON_SRC}/icon-1024.png" "${APP}"
rm -rf "${ICON_SRC}"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${APP}" >/dev/null

echo "Built: ${APP}"
echo "Double-click Aotbox.app. Do not double-click the aotbox-gui binary."
