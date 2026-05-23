#include <gst/gst.h>
#include "music-application.h"

int
main (int argc, char *argv[])
{
  gst_init (&argc, &argv);

  g_autoptr (MusicApplication) app = music_application_new ();
  return g_application_run (G_APPLICATION (app), argc, argv);
}
