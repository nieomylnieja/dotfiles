/* user and group to drop privileges to */
static const char *user  = "mhawrus";
static const char *group = "mhawrus";

static const char *colorname[NUMCOLS] = {
	[INIT]   =  "#5E81AC",   /* after initialization */
	[INPUT]  =  "#8FBCBB",   /* during input */
	[FAILED] =  "#BF616A",   /* wrong password */
	[CAPS]   =  "red",       /* CapsLock on */
};

/* treat a cleared input like a wrong password (color) */
static const int failonclear = 0;

/* insert grid pattern with scale 1:1, the size can be changed with logosize */
static const int logosize = 75;
/* grid width and height for right center alignment */
static const int logow = 12;
static const int logoh = 6;

/*Seplls HWM*/
static XRectangle rectangles[9] = {
	/* x    y       w       h */
	{ 0,    0,      1,      6 },
	{ 1,    3,      2,      1 },
	{ 3,    5,      5,      1 },
	{ 3,    0,      1,      5 },
	{ 5,    3,      1,      2 },
	{ 7,    3,      1,      2 },
	{ 8,    3,      4,      1 },
	{ 9,    4,      1,      2 },
	{ 11,   4,      1,      2 },
};

/*Enable blur*/
#define BLUR
/*Set blur radius*/
static const int blurRadius=7;
/*Enable Pixelation*/
//#define PIXELATION
/*Set pixelation radius*/
/* static const int pixelSize=0; */

// DPMS
/* time in seconds before the monitor shuts down */
static const int monitortime = 300;

// QuickCancel
/* time in seconds to cancel lock with mouse movement */
static const int timetocancel = 4;

// ColorMessage
/* default message */
static const char * message = "Can't touch this.";

/* text color */
static const char * text_color = "#D8DEE9";

/* text size (must be a valid size) */
static const char * font_name = "12x24";
