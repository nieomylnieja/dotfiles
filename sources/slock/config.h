/* user and group to drop privileges to */
static const char *user  = "mh";
static const char *group = "mh";

static const char *colorname[NUMCOLS] = {
	[INIT]   =  "#2E3440",   /* after initialization */
	[INPUT]  =  "#4C566A",   /* during input */
	[FAILED] =  "#BF616A",   /* wrong password */
	[CAPS]   =  "red",       /* CapsLock on */
};

/* treat a cleared input like a wrong password (color) */
static const int failonclear = 1;

/* time in seconds before the monitor shuts down */
static const int monitortime = 300;

/* default message */
static const char * message = "Can't touch this.";

/* text color */
static const char * text_color = "#D8DEE9";

/* text size (must be a valid size) */
static const char * font_name = "6x13";
