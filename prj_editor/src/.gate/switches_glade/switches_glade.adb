with Gtk; use Gtk;
with Gtk.Main;
with Gtk.Widget; use Gtk.Widget;
with Switches_Editor_Pkg; use Switches_Editor_Pkg;

procedure Switches_Glade is
begin
   Gtk.Main.Set_Locale;
   Gtk.Main.Init;
   Gtk_New (Switches_Editor);
   Show_All (Switches_Editor);
   Gtk.Main.Main;
end Switches_Glade;
