with Gtk; use Gtk;
with Gtk.Main;
with Gtk.Widget; use Gtk.Widget;
with Switches_Editor_Pkg; use Switches_Editor_Pkg;
with Naming_Scheme_Editor_Pkg; use Naming_Scheme_Editor_Pkg;
with Variable_Editor_Pkg; use Variable_Editor_Pkg;
with New_Variable_Editor_Pkg; use New_Variable_Editor_Pkg;

procedure Switches_Glade is
begin
   Gtk.Main.Set_Locale;
   Gtk.Main.Init;
   Gtk_New (Switches_Editor);
   Show_All (Switches_Editor);
   Gtk_New (Naming_Scheme_Editor);
   Show_All (Naming_Scheme_Editor);
   Gtk_New (Variable_Editor);
   Show_All (Variable_Editor);
   Gtk_New (New_Variable_Editor);
   Show_All (New_Variable_Editor);
   Gtk.Main.Main;
end Switches_Glade;
