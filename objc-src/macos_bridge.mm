#include <AppKit/AppKit.h>
#include <phpx.h>

#include <cfloat>
#include <cstring>

static NSString *to_ns_string(const php::Str &value)
{
    NSString *result = [[NSString alloc] initWithBytes:value.data()
                                                length:value.length()
                                              encoding:NSUTF8StringEncoding];
    return result == nil ? @"" : result;
}

static php::Str to_php_string(NSString *value)
{
    if (value == nil) {
        return php::Str("", 0);
    }
    const char *utf8 = value.UTF8String;
    return php::Str(utf8, std::strlen(utf8));
}

@interface TypePHPAppKitBridge : NSObject <NSWindowDelegate>

@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSView *> *controls;
@property(nonatomic) NSInteger nextControlId;
@property(nonatomic) NSInteger pendingControlId;
@property(nonatomic) BOOL running;
@property(nonatomic, strong) NSMutableArray<NSTextView *> *textViews;

- (void)controlActivated:(NSControl *)sender;
- (void)showFind:(id)sender;

@end

@implementation TypePHPAppKitBridge

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        self.controls = [[NSMutableDictionary alloc] init];
        self.textViews = [[NSMutableArray alloc] init];
        self.nextControlId = 1;
    }
    return self;
}

- (void)controlActivated:(NSControl *)sender
{
    self.pendingControlId = sender.tag;
}

- (void)windowWillClose:(NSNotification *)notification
{
    (void) notification;
    self.running = NO;
}

- (NSTextView *)textViewForFind
{
    id responder = self.window.firstResponder;
    if ([responder isKindOfClass:NSTextView.class]) {
        return (NSTextView *)responder;
    }
    // The find field is an NSTextField inside the text view's scroll view.
    // Walk up so Find Next stays on the view already being searched.
    if ([responder isKindOfClass:NSView.class]) {
        NSView *view = (NSView *)responder;
        while (view != nil) {
            if ([view isKindOfClass:NSScrollView.class]) {
                id document = ((NSScrollView *)view).documentView;
                if ([document isKindOfClass:NSTextView.class] && [self.textViews containsObject:document]) {
                    return (NSTextView *)document;
                }
            }
            view = view.superview;
        }
    }
    return self.textViews.lastObject;
}

- (void)showFind:(id)sender
{
    NSTextView *target = [self textViewForFind];
    if (target == nil) {
        return;
    }
    [self.window makeFirstResponder:target];
    [target performFindPanelAction:sender];
}

@end

static __strong TypePHPAppKitBridge *bridge = nil;

static void install_application_menu(NSString *applicationName)
{
    NSMenu *menuBar = [[NSMenu alloc] init];
    NSMenuItem *applicationMenuItem = [[NSMenuItem alloc] init];
    [menuBar addItem:applicationMenuItem];
    NSApp.mainMenu = menuBar;

    NSMenu *applicationMenu = [[NSMenu alloc] init];
    NSString *quitTitle = [@"Quit " stringByAppendingString:applicationName];
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:quitTitle
                                                    action:@selector(terminate:)
                                             keyEquivalent:@"q"];
    [applicationMenu addItem:quitItem];
    applicationMenuItem.submenu = applicationMenu;

    // Edit menu. Without it, NSTextField/NSTextView cannot receive the
    // standard editing commands (Cmd+C/V/X/A, undo/redo): those key
    // equivalents are resolved through the menu bar, not by the views.
    NSMenuItem *editMenuItem = [[NSMenuItem alloc] initWithTitle:@"Edit" action:NULL keyEquivalent:@""];
    [menuBar addItem:editMenuItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    [editMenu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"Z"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:@""];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    // Target the bridge so Find stays enabled after a button click. showFind:
    // searches the focused text view, or the output view when focus is elsewhere.
    NSMenuItem *findItem = [[NSMenuItem alloc] initWithTitle:@"查找"
                                                     action:@selector(showFind:)
                                              keyEquivalent:@"f"];
    findItem.target = bridge;
    findItem.tag = NSTextFinderActionShowFindInterface;
    [editMenu addItem:findItem];
    NSMenuItem *findNextItem = [[NSMenuItem alloc] initWithTitle:@"查找下一个"
                                                         action:@selector(showFind:)
                                                  keyEquivalent:@"g"];
    findNextItem.target = bridge;
    findNextItem.tag = NSTextFinderActionNextMatch;
    [editMenu addItem:findNextItem];
    NSMenuItem *findPrevItem = [[NSMenuItem alloc] initWithTitle:@"查找上一个"
                                                         action:@selector(showFind:)
                                                  keyEquivalent:@"G"];
    findPrevItem.target = bridge;
    findPrevItem.tag = NSTextFinderActionPreviousMatch;
    [editMenu addItem:findPrevItem];
    editMenuItem.submenu = editMenu;
}

static NSInteger store_control(NSView *control)
{
    const NSInteger controlId = bridge.nextControlId++;
    bridge.controls[@(controlId)] = control;
    // NSButton's tag defaults to -1. The event loop treats any negative id as
    // "window closed", so an unset tag makes every click quit the app.
    // Ids start at 1, which also keeps them distinct from the "no event" sentinel 0.
    if ([control isKindOfClass:NSControl.class]) {
        ((NSControl *)control).tag = controlId;
    }
    return controlId;
}

static NSView *control_by_id(php::Int controlId)
{
    return bridge.controls[@(static_cast<NSInteger>(controlId))];
}

static NSImage *make_app_icon(void)
{
    const NSSize canvas = NSMakeSize(512, 512);
    return [NSImage imageWithSize:canvas flipped:NO drawingHandler:^BOOL(NSRect rect) {
        const CGFloat pad = 18;
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

        NSFont *font = [NSFont monospacedSystemFontOfSize:150 weight:NSFontWeightBold];
        NSDictionary *attrs = @{
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: NSColor.whiteColor
        };
        NSString *mark = @"{ }";
        NSSize textSize = [mark sizeWithAttributes:attrs];
        NSPoint origin = NSMakePoint(NSMidX(box) - textSize.width / 2.0,
                                     NSMidY(box) - textSize.height / 2.0 + 18);
        [mark drawAtPoint:origin withAttributes:attrs];
        return YES;
    }];
}

void php_ui_app_init(php::Str applicationName)
{
    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        application.activationPolicy = NSApplicationActivationPolicyRegular;
        application.applicationIconImage = make_app_icon();
        bridge = [[TypePHPAppKitBridge alloc] init];
        install_application_menu(to_ns_string(applicationName));
        [application finishLaunching];
    }
}

void php_ui_create_window(php::Str title, php::Int width, php::Int height)
{
    @autoreleasepool {
        const NSRect frame = NSMakeRect(0, 0, static_cast<CGFloat>(width), static_cast<CGFloat>(height));
        const NSWindowStyleMask style = NSWindowStyleMaskTitled |
                                        NSWindowStyleMaskClosable |
                                        NSWindowStyleMaskMiniaturizable |
                                        NSWindowStyleMaskResizable;
        bridge.window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
        bridge.window.releasedWhenClosed = NO;
        bridge.window.delegate = bridge;
        bridge.window.title = to_ns_string(title);
        bridge.window.minSize = NSMakeSize(640, 480);
        [bridge.window center];
    }
}

php::Int php_ui_add_label(
    php::Str text,
    php::Int x,
    php::Int y,
    php::Int width,
    php::Int height,
    php::Int fontSize,
    php::Bool bold)
{
    @autoreleasepool {
        NSTextField *label = [NSTextField labelWithString:to_ns_string(text)];
        label.frame = NSMakeRect(
            static_cast<CGFloat>(x),
            static_cast<CGFloat>(y),
            static_cast<CGFloat>(width),
            static_cast<CGFloat>(height));
        label.font = bold
                         ? [NSFont systemFontOfSize:static_cast<CGFloat>(fontSize)
                                            weight:NSFontWeightSemibold]
                         : [NSFont systemFontOfSize:static_cast<CGFloat>(fontSize)];
        label.textColor = bold ? NSColor.labelColor : NSColor.secondaryLabelColor;
        [bridge.window.contentView addSubview:label];
        return static_cast<php::Int>(store_control(label));
    }
}

php::Int php_ui_add_button(
    php::Str title,
    php::Int x,
    php::Int y,
    php::Int width,
    php::Int height,
    php::Int style)
{
    @autoreleasepool {
        NSButton *button = [NSButton buttonWithTitle:to_ns_string(title)
                                              target:bridge
                                              action:@selector(controlActivated:)];
        button.frame = NSMakeRect(
            static_cast<CGFloat>(x),
            static_cast<CGFloat>(y),
            static_cast<CGFloat>(width),
            static_cast<CGFloat>(height));
        button.controlSize = NSControlSizeRegular;
        button.font = [NSFont systemFontOfSize:13];
        if (static_cast<NSInteger>(style) == 1) {
            button.bezelColor = NSColor.controlAccentColor;
            button.contentTintColor = NSColor.whiteColor;
            button.keyEquivalent = @"\r";
        }
        [bridge.window.contentView addSubview:button];
        return static_cast<php::Int>(store_control(button));
    }
}

php::Int php_ui_add_text_field(
    php::Str text,
    php::Int x,
    php::Int y,
    php::Int width,
    php::Int height)
{
    @autoreleasepool {
        NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(
            static_cast<CGFloat>(x),
            static_cast<CGFloat>(y),
            static_cast<CGFloat>(width),
            static_cast<CGFloat>(height))];
        field.stringValue = to_ns_string(text);
        field.font = [NSFont systemFontOfSize:13];
        field.bezeled = YES;
        field.bezelStyle = NSTextFieldRoundedBezel;
        field.editable = YES;
        field.selectable = YES;
        [bridge.window.contentView addSubview:field];
        return static_cast<php::Int>(store_control(field));
    }
}

php::Int php_ui_add_text_view(
    php::Str text,
    php::Int x,
    php::Int y,
    php::Int width,
    php::Int height)
{
    @autoreleasepool {
        NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(
            static_cast<CGFloat>(x),
            static_cast<CGFloat>(y),
            static_cast<CGFloat>(width),
            static_cast<CGFloat>(height))];
        scroll.hasVerticalScroller = YES;
        scroll.borderType = NSBezelBorder;
        scroll.autoresizingMask = NSViewWidthSizable;

        const NSSize contentSize = scroll.contentSize;
        NSTextView *tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, contentSize.width, contentSize.height)];
        tv.minSize = NSMakeSize(0.0, contentSize.height);
        tv.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
        tv.verticallyResizable = YES;
        tv.horizontallyResizable = NO;
        tv.autoresizingMask = NSViewWidthSizable;
        tv.textContainer.containerSize = NSMakeSize(contentSize.width, FLT_MAX);
        tv.textContainer.widthTracksTextView = YES;
        tv.font = [NSFont systemFontOfSize:13];
        tv.selectable = YES;
        tv.usesFindBar = YES;
        tv.incrementalSearchingEnabled = YES;
        tv.string = to_ns_string(text);
        [bridge.textViews addObject:tv];

        [scroll setDocumentView:tv];
        [bridge.window.contentView addSubview:scroll];
        return static_cast<php::Int>(store_control(tv));
    }
}

static BOOL json_ws(unichar c)
{
    return c == ' ' || c == '\n' || c == '\r' || c == '\t';
}

struct JsonHighlighter {
    NSString *__unsafe_unretained text;
    NSMutableAttributedString *__unsafe_unretained out;
    NSUInteger index;
    int depth;
    BOOL coloring;
};

static void paint_range(NSMutableAttributedString *out, NSUInteger loc, NSUInteger len, NSColor *color)
{
    if (len == 0 || loc + len > out.length) {
        return;
    }
    [out addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(loc, len)];
}

static void paint(JsonHighlighter *h, NSUInteger loc, NSUInteger len, NSColor *color)
{
    if (!h->coloring) {
        return;
    }
    paint_range(h->out, loc, len, color);
}

static void skip_ws(JsonHighlighter *h)
{
    const NSUInteger n = h->text.length;
    while (h->index < n && json_ws([h->text characterAtIndex:h->index])) {
        h->index++;
    }
}

static BOOL parse_value(JsonHighlighter *h);

static BOOL parse_string(JsonHighlighter *h, BOOL key)
{
    const NSUInteger n = h->text.length;
    const NSUInteger start = h->index;
    if (h->index >= n || [h->text characterAtIndex:h->index] != '"') {
        return NO;
    }
    h->index++;
    while (h->index < n) {
        const unichar c = [h->text characterAtIndex:h->index];
        if (c == '\\') {
            if (h->index + 1 >= n) {
                return NO;
            }
            h->index += 2;
            continue;
        }
        h->index++;
        if (c == '"') {
            paint(h, start, h->index - start, key ? NSColor.systemBlueColor : NSColor.systemGreenColor);
            return YES;
        }
    }
    return NO;
}

static BOOL parse_literal(JsonHighlighter *h, NSString *word)
{
    const NSUInteger n = word.length;
    if (h->index + n > h->text.length) {
        return NO;
    }
    if (![[h->text substringWithRange:NSMakeRange(h->index, n)] isEqualToString:word]) {
        return NO;
    }
    if (h->index + n < h->text.length) {
        const unichar next = [h->text characterAtIndex:h->index + n];
        const BOOL word_char = (next >= 'a' && next <= 'z') || (next >= 'A' && next <= 'Z') ||
                               (next >= '0' && next <= '9') || next == '_';
        if (word_char) {
            return NO;
        }
    }
    paint(h, h->index, n, NSColor.systemOrangeColor);
    h->index += n;
    return YES;
}

static BOOL parse_number(JsonHighlighter *h)
{
    const NSUInteger n = h->text.length;
    const NSUInteger start = h->index;
    if (h->index < n && [h->text characterAtIndex:h->index] == '-') {
        h->index++;
    }
    if (h->index >= n) {
        return NO;
    }
    const unichar first = [h->text characterAtIndex:h->index];
    if (first < '0' || first > '9') {
        return NO;
    }
    if (first == '0') {
        h->index++;
    } else {
        while (h->index < n) {
            const unichar c = [h->text characterAtIndex:h->index];
            if (c < '0' || c > '9') {
                break;
            }
            h->index++;
        }
    }
    if (h->index < n && [h->text characterAtIndex:h->index] == '.') {
        h->index++;
        const NSUInteger fraction = h->index;
        while (h->index < n) {
            const unichar c = [h->text characterAtIndex:h->index];
            if (c < '0' || c > '9') {
                break;
            }
            h->index++;
        }
        if (h->index == fraction) {
            return NO;
        }
    }
    if (h->index < n) {
        const unichar exp = [h->text characterAtIndex:h->index];
        if (exp == 'e' || exp == 'E') {
            h->index++;
            if (h->index < n) {
                const unichar sign = [h->text characterAtIndex:h->index];
                if (sign == '+' || sign == '-') {
                    h->index++;
                }
            }
            const NSUInteger exp_digits = h->index;
            while (h->index < n) {
                const unichar c = [h->text characterAtIndex:h->index];
                if (c < '0' || c > '9') {
                    break;
                }
                h->index++;
            }
            if (h->index == exp_digits) {
                return NO;
            }
        }
    }
    paint(h, start, h->index - start, NSColor.systemPurpleColor);
    return YES;
}

static BOOL parse_object(JsonHighlighter *h)
{
    if (++h->depth > 64) {
        return NO;
    }
    paint(h, h->index, 1, NSColor.secondaryLabelColor);
    h->index++;
    skip_ws(h);
    if (h->index < h->text.length && [h->text characterAtIndex:h->index] == '}') {
        paint(h, h->index, 1, NSColor.secondaryLabelColor);
        h->index++;
        h->depth--;
        return YES;
    }
    while (h->index < h->text.length) {
        if (!parse_string(h, YES)) {
            return NO;
        }
        skip_ws(h);
        if (h->index >= h->text.length || [h->text characterAtIndex:h->index] != ':') {
            return NO;
        }
        paint(h, h->index, 1, NSColor.secondaryLabelColor);
        h->index++;
        if (!parse_value(h)) {
            return NO;
        }
        skip_ws(h);
        if (h->index >= h->text.length) {
            return NO;
        }
        const unichar c = [h->text characterAtIndex:h->index];
        if (c == ',') {
            paint(h, h->index, 1, NSColor.secondaryLabelColor);
            h->index++;
            skip_ws(h);
            continue;
        }
        if (c == '}') {
            paint(h, h->index, 1, NSColor.secondaryLabelColor);
            h->index++;
            h->depth--;
            return YES;
        }
        return NO;
    }
    return NO;
}

static BOOL parse_array(JsonHighlighter *h)
{
    if (++h->depth > 64) {
        return NO;
    }
    paint(h, h->index, 1, NSColor.secondaryLabelColor);
    h->index++;
    skip_ws(h);
    if (h->index < h->text.length && [h->text characterAtIndex:h->index] == ']') {
        paint(h, h->index, 1, NSColor.secondaryLabelColor);
        h->index++;
        h->depth--;
        return YES;
    }
    while (h->index < h->text.length) {
        if (!parse_value(h)) {
            return NO;
        }
        skip_ws(h);
        if (h->index >= h->text.length) {
            return NO;
        }
        const unichar c = [h->text characterAtIndex:h->index];
        if (c == ',') {
            paint(h, h->index, 1, NSColor.secondaryLabelColor);
            h->index++;
            skip_ws(h);
            continue;
        }
        if (c == ']') {
            paint(h, h->index, 1, NSColor.secondaryLabelColor);
            h->index++;
            h->depth--;
            return YES;
        }
        return NO;
    }
    return NO;
}

static BOOL parse_value(JsonHighlighter *h)
{
    skip_ws(h);
    if (h->index >= h->text.length) {
        return NO;
    }
    const unichar c = [h->text characterAtIndex:h->index];
    if (c == '"') {
        return parse_string(h, NO);
    }
    if (c == '{') {
        return parse_object(h);
    }
    if (c == '[') {
        return parse_array(h);
    }
    if (c == 't') {
        return parse_literal(h, @"true");
    }
    if (c == 'f') {
        return parse_literal(h, @"false");
    }
    if (c == 'n') {
        return parse_literal(h, @"null");
    }
    if (c == '-' || (c >= '0' && c <= '9')) {
        return parse_number(h);
    }
    return NO;
}

// Colors a text view when `text` is one complete JSON value. Returns NO for
// anything else so callers can fall back to plain text.
static BOOL apply_json_highlight(NSTextView *tv, NSString *text)
{
    if (text.length == 0) {
        return NO;
    }
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:text];
    NSFont *font = [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular];
    [attr addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, text.length)];
    [attr addAttribute:NSForegroundColorAttributeName value:NSColor.labelColor range:NSMakeRange(0, text.length)];
    JsonHighlighter highlighter{text, attr, 0, 0, YES};
    if (!parse_value(&highlighter)) {
        return NO;
    }
    skip_ws(&highlighter);
    if (highlighter.index != text.length) {
        return NO;
    }
    [tv.textStorage setAttributedString:attr];
    return YES;
}

static BOOL color_embedded_json(NSMutableAttributedString *attr, NSString *text)
{
    BOOL any = NO;
    const NSUInteger n = text.length;
    NSUInteger i = 0;
    while (i < n) {
        const unichar c = [text characterAtIndex:i];
        if (c == '{' || c == '[') {
            JsonHighlighter probe{text, attr, i, 0, NO};
            if (parse_value(&probe) && probe.index > i) {
                JsonHighlighter commit{text, attr, i, 0, YES};
                parse_value(&commit);
                any = YES;
                i = commit.index;
                continue;
            }
        }
        i++;
    }
    return any;
}

static BOOL is_b64url_part(NSString *part)
{
    if (part.length < 8) {
        return NO;
    }
    for (NSUInteger i = 0; i < part.length; i++) {
        const unichar c = [part characterAtIndex:i];
        const BOOL ok = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' ||
                        c == '_';
        if (!ok) {
            return NO;
        }
    }
    return YES;
}

// A compact JWT is three base64url segments. Header, payload and signature
// each get their own color so the token is readable without decoding it.
static BOOL color_jwt_token(NSMutableAttributedString *attr, NSString *text)
{
    if ([text rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location != NSNotFound) {
        return NO;
    }
    NSArray<NSString *> *parts = [text componentsSeparatedByString:@"."];
    if (parts.count != 3) {
        return NO;
    }
    for (NSString *part in parts) {
        if (!is_b64url_part(part)) {
            return NO;
        }
    }
    NSColor *colors[3] = {NSColor.systemBlueColor, NSColor.systemGreenColor, NSColor.systemPurpleColor};
    NSUInteger loc = 0;
    for (NSUInteger i = 0; i < 3; i++) {
        paint_range(attr, loc, parts[i].length, colors[i]);
        loc += parts[i].length;
        if (i < 2) {
            paint_range(attr, loc, 1, NSColor.secondaryLabelColor);
            loc += 1;
        }
    }
    return YES;
}

static NSColor *jwt_status_color(NSString *text)
{
    if ([text hasPrefix:@"签名有效"]) {
        return NSColor.systemGreenColor;
    }
    if ([text hasPrefix:@"签名校验失败"]) {
        return NSColor.systemRedColor;
    }
    if ([text hasPrefix:@"未校验签名"]) {
        return NSColor.systemOrangeColor;
    }
    return nil;
}

// JWT decode text is a status line plus JSON blocks, not one JSON value.
static BOOL apply_mixed_highlight(NSTextView *tv, NSString *text)
{
    if (text.length == 0) {
        return NO;
    }
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:text];
    NSFont *font = [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular];
    [attr addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, text.length)];
    [attr addAttribute:NSForegroundColorAttributeName value:NSColor.labelColor range:NSMakeRange(0, text.length)];

    BOOL any = NO;
    NSColor *status = jwt_status_color(text);
    if (status != nil) {
        NSRange newline = [text rangeOfString:@"\n"];
        const NSUInteger len = newline.location == NSNotFound ? text.length : newline.location;
        paint_range(attr, 0, len, status);
        any = YES;
    }
    if (color_jwt_token(attr, text) || color_embedded_json(attr, text)) {
        any = YES;
    }
    if (!any) {
        return NO;
    }
    [tv.textStorage setAttributedString:attr];
    return YES;
}

void php_ui_set_control_text(php::Int controlId, php::Str text)
{
    @autoreleasepool {
        NSView *control = control_by_id(controlId);
        if (control == nil) {
            return;
        }
        NSString *value = to_ns_string(text);
        if ([control isKindOfClass:NSButton.class]) {
            ((NSButton *)control).title = value;
        } else if ([control isKindOfClass:NSTextField.class]) {
            ((NSTextField *)control).stringValue = value;
        } else if ([control isKindOfClass:NSTextView.class]) {
            NSTextView *tv = (NSTextView *)control;
            if (!apply_json_highlight(tv, value) && !apply_mixed_highlight(tv, value)) {
                tv.font = [NSFont systemFontOfSize:13];
                tv.textColor = NSColor.labelColor;
                tv.string = value;
            }
        }
    }
}

php::Str php_ui_get_control_text(php::Int controlId)
{
    @autoreleasepool {
        NSView *control = control_by_id(controlId);
        if (control == nil) {
            return php::Str("", 0);
        }
        if ([control isKindOfClass:NSTextField.class]) {
            return to_php_string(((NSTextField *)control).stringValue);
        }
        if ([control isKindOfClass:NSTextView.class]) {
            return to_php_string(((NSTextView *)control).string);
        }
        return php::Str("", 0);
    }
}

void php_ui_set_control_editable(php::Int controlId, php::Bool editable)
{
    @autoreleasepool {
        NSView *control = control_by_id(controlId);
        if (control == nil) {
            return;
        }
        if ([control isKindOfClass:NSTextField.class]) {
            ((NSTextField *)control).editable = static_cast<BOOL>(editable);
        } else if ([control isKindOfClass:NSTextView.class]) {
            ((NSTextView *)control).editable = static_cast<BOOL>(editable);
        }
    }
}

void php_ui_set_control_visible(php::Int controlId, php::Bool visible)
{
    @autoreleasepool {
        NSView *control = control_by_id(controlId);
        if (control == nil) {
            return;
        }
        NSView *target = control;
        if ([control isKindOfClass:NSTextView.class] && ((NSTextView *)control).enclosingScrollView != nil) {
            target = ((NSTextView *)control).enclosingScrollView;
        }
        target.hidden = !static_cast<BOOL>(visible);
    }
}

void php_ui_show_window()
{
    @autoreleasepool {
        [bridge.window makeKeyAndOrderFront:nil];
        bridge.running = YES;
        [NSApp activateIgnoringOtherApps:YES];
    }
}

php::Int php_ui_next_event()
{
    while (bridge.running) {
        @autoreleasepool {
            NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                                untilDate:NSDate.distantFuture
                                                   inMode:NSDefaultRunLoopMode
                                                  dequeue:YES];
            if (event != nil) {
                [NSApp sendEvent:event];
                [NSApp updateWindows];
            }

            if (bridge.pendingControlId != 0) {
                const NSInteger controlId = bridge.pendingControlId;
                bridge.pendingControlId = 0;
                return static_cast<php::Int>(controlId);
            }
        }
    }
    return -1;
}
