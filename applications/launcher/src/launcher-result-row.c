#include "launcher-result-row.h"

struct _LauncherResultRow
{
  GtkBox parent_instance;
};

G_DEFINE_FINAL_TYPE (LauncherResultRow, launcher_result_row, GTK_TYPE_BOX)

static void
launcher_result_row_class_init (LauncherResultRowClass *klass)
{
  (void) klass;
}

static void
launcher_result_row_init (LauncherResultRow *self)
{
  gtk_orientable_set_orientation (GTK_ORIENTABLE (self), GTK_ORIENTATION_HORIZONTAL);
  gtk_box_set_spacing (GTK_BOX (self), 14);
  gtk_widget_set_margin_start (GTK_WIDGET (self), 12);
  gtk_widget_set_margin_end (GTK_WIDGET (self), 12);
  gtk_widget_set_margin_top (GTK_WIDGET (self), 8);
  gtk_widget_set_margin_bottom (GTK_WIDGET (self), 8);
}

static void
set_icon (GtkImage *image, LauncherResult *result)
{
  switch (launcher_result_get_kind (result))
    {
    case LAUNCHER_RESULT_APP:
      {
        GIcon *icon = g_app_info_get_icon (launcher_result_get_app_info (result));
        if (icon != NULL)
          gtk_image_set_from_gicon (image, icon);
        else
          gtk_image_set_from_icon_name (image, "application-x-executable");
        break;
      }
    case LAUNCHER_RESULT_CALC:
      gtk_image_set_from_resource (image, "/dev/sandip/Launcher/icons/calculator.svg");
      break;
    case LAUNCHER_RESULT_GOOGLE:
      gtk_image_set_from_resource (image, "/dev/sandip/Launcher/icons/web.svg");
      break;
    default:
      g_assert_not_reached ();
    }
}

GtkWidget *
launcher_result_row_new (LauncherResult *result)
{
  LauncherResultRow *self = g_object_new (LAUNCHER_TYPE_RESULT_ROW, NULL);

  GtkWidget *image = gtk_image_new ();
  gtk_image_set_pixel_size (GTK_IMAGE (image), 32);
  gtk_widget_set_valign (image, GTK_ALIGN_CENTER);
  set_icon (GTK_IMAGE (image), result);
  gtk_box_append (GTK_BOX (self), image);

  GtkWidget *text = gtk_box_new (GTK_ORIENTATION_VERTICAL, 2);
  gtk_widget_set_valign (text, GTK_ALIGN_CENTER);
  gtk_widget_set_hexpand (text, TRUE);

  GtkWidget *title = gtk_label_new (launcher_result_get_title (result));
  gtk_widget_add_css_class (title, "result-title");
  gtk_widget_set_halign (title, GTK_ALIGN_START);
  gtk_label_set_xalign (GTK_LABEL (title), 0.0f);
  gtk_label_set_ellipsize (GTK_LABEL (title), PANGO_ELLIPSIZE_END);
  gtk_box_append (GTK_BOX (text), title);

  const char *subtitle = launcher_result_get_subtitle (result);
  if (subtitle != NULL && *subtitle != '\0')
    {
      GtkWidget *sub = gtk_label_new (subtitle);
      gtk_widget_add_css_class (sub, "result-subtitle");
      gtk_widget_set_halign (sub, GTK_ALIGN_START);
      gtk_label_set_xalign (GTK_LABEL (sub), 0.0f);
      gtk_label_set_ellipsize (GTK_LABEL (sub), PANGO_ELLIPSIZE_END);
      gtk_box_append (GTK_BOX (text), sub);
    }

  gtk_box_append (GTK_BOX (self), text);

  return GTK_WIDGET (self);
}
