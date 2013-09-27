------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2008-2013, AdaCore                     --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

with Ada.Numerics;
with System;
with Interfaces.C.Strings;     use Interfaces.C.Strings;

with Cairo;                    use Cairo;
with Glib.Main;                use Glib.Main;
with Glib.Object;              use Glib.Object;
with Gdk.Device;               use Gdk.Device;
with Gdk.Event;                use Gdk.Event;
with Gdk.Window;               use Gdk.Window;
with Gtk.Box;                  use Gtk.Box;
with Gtk.Handlers;             use Gtk.Handlers;
with Gtk.Icon_Factory;         use Gtk.Icon_Factory;
with Gtk.Image;                use Gtk.Image;
with Gtk.Label;                use Gtk.Label;
with Gtk.Menu_Item;            use Gtk.Menu_Item;
with Gtk.Style_Context;        use Gtk.Style_Context;
with Gtk.Widget;               use Gtk.Widget;
with Gtkada.Handlers;          use Gtkada.Handlers;

package body Gtkada.Combo_Tool_Button is

   ----------------------
   -- Class definition --
   ----------------------

   Class_Record : aliased Ada_GObject_Class := Uninitialized_Class;
   Signals : constant chars_ptr_array :=
     (1 => New_String (String (Signal_Selection_Changed)));

   ---------------
   -- Menu_Item --
   ---------------

   type Menu_Item_Record is new Gtk_Menu_Item_Record with record
      Stock_Id : Unbounded_String;
      Label    : Gtk_Label;
      Data     : User_Data;
   end record;
   type Menu_Item is access all Menu_Item_Record'Class;

   procedure Gtk_New
     (Item     : out Menu_Item;
      Label    : String;
      Stock_Id : String;
      Data     : User_Data);

   procedure Set_Highlight
     (Item  : access Menu_Item_Record'Class;
      State : Boolean);

   procedure On_Destroy (Self : access Gtk_Widget_Record'Class);
   --  Called when the tool_button is destroyed.

   --------------
   -- Handlers --
   --------------

   package Items_Callback is new Gtk.Handlers.User_Callback
     (Menu_Item_Record, Gtkada_Combo_Tool_Button);

   package Menu_Popup is new Popup_For_Device_User_Data
     (Gtkada_Combo_Tool_Button);

   ---------------------------
   -- Callback declarations --
   ---------------------------

   package Button_Sources is new Glib.Main.Generic_Sources
     (Gtkada_Combo_Tool_Button);

   function On_Long_Click (Self : Gtkada_Combo_Tool_Button) return Boolean;
   --  Called when the user had kept the button pressed for a long time.

   function On_Button_Press
     (Button : access GObject_Record'Class;
      Event  : Gdk_Event_Button) return Boolean;
   function On_Button_Release
     (Button : access GObject_Record'Class;
      Event  : Gdk_Event_Button) return Boolean;
   function On_Menu_Button_Release
     (Button : access GObject_Record'Class;
      Event  : Gdk_Event_Button) return Boolean;

   procedure Menu_Detacher
     (Attach_Widget : System.Address; Menu : System.Address);
   pragma Convention (C, Menu_Detacher);

   procedure Menu_Position
     (Menu    : not null access Gtk_Menu_Record'Class;
      X       : out Gint;
      Y       : out Gint;
      Push_In : out Boolean;
      Widget  : Gtkada_Combo_Tool_Button);

   procedure On_Menu_Item_Activated
     (Item   : access Menu_Item_Record'Class;
      Widget : Gtkada_Combo_Tool_Button);

   procedure Popdown
     (Self : not null access Gtkada_Combo_Tool_Button_Record'Class);
   --  Hide the popup menu

   function On_Draw
     (Self : access GObject_Record'Class;
      Cr   : Cairo.Cairo_Context) return Boolean;

   function Get_Button
     (Self : not null access Gtkada_Combo_Tool_Button_Record'Class)
      return Gtk_Widget;
   --  Return the internal button widget used by a GtkToolButton.

   ----------------
   -- Get_Button --
   ----------------

   function Get_Button
     (Self : not null access Gtkada_Combo_Tool_Button_Record'Class)
      return Gtk_Widget is
   begin
      return Self.Get_Child;
   end Get_Button;

   -------------
   -- Popdown --
   -------------

   procedure Popdown
     (Self : not null access Gtkada_Combo_Tool_Button_Record'Class) is
   begin
      if Self.Menu /= null and then Self.Menu.Get_Visible then
         Self.Menu.Deactivate;
      end if;
   end Popdown;

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (Item     : out Menu_Item;
      Label    : String;
      Stock_Id : String;
      Data     : User_Data)
   is
      Icon : Gtk_Image;
      Hbox : Gtk_Hbox;
   begin
      Item := new Menu_Item_Record;
      Gtk.Menu_Item.Initialize (Item);

      Item.Data     := Data;
      Item.Stock_Id := To_Unbounded_String (Stock_Id);

      Gtk_New_Hbox (Hbox, Homogeneous => False, Spacing => 5);
      Item.Add (Hbox);

      Gtk_New (Icon, Stock_Id, Icon_Size_Menu);
      Hbox.Pack_Start (Icon, False, False, 0);

      Gtk_New (Item.Label, Label);
      Item.Label.Set_Alignment (0.0, 0.5);
      Item.Label.Set_Use_Markup (True);
      Hbox.Pack_Start (Item.Label, True, True, 0);
      Show_All (Item);
   end Gtk_New;

   -------------------
   -- Set_Highlight --
   -------------------

   procedure Set_Highlight
     (Item  : access Menu_Item_Record'Class;
      State : Boolean) is
   begin
      if State then
         Item.Label.Set_Label ("<b>" & Item.Label.Get_Text & "</b>");
      else
         Item.Label.Set_Label (Item.Label.Get_Text);
      end if;
   end Set_Highlight;

   -------------
   -- On_Draw --
   -------------

   function On_Draw
     (Self : access GObject_Record'Class;
      Cr   : Cairo.Cairo_Context) return Boolean
   is
      B : constant Gtkada_Combo_Tool_Button :=
        Gtkada_Combo_Tool_Button (Self);
      W, H    : Gint;
      Result  : Boolean;
      Alloc   : Gtk_Allocation;
      Size : constant Gdouble := 6.0;
   begin
      if not B.Items.Is_Empty then
         Icon_Size_Lookup (B.Get_Icon_Size, W, H, Result);
         B.Get_Allocation (Alloc);
         Get_Style_Context (B).Render_Arrow
           (Cr    => Cr,
            Angle => Gdouble (Ada.Numerics.Pi),
            X     => Gdouble (Alloc.Width) - Size - 1.0,
            Y     => Gdouble ((Alloc.Height + H) / 2) - Size,
            Size  => Size);
      end if;
      return False;
   end On_Draw;

   ---------------------
   -- On_Button_Press --
   ---------------------

   function On_Button_Press
     (Button : access GObject_Record'Class;
      Event  : Gdk_Event_Button) return Boolean
   is
      B : constant Gtkada_Combo_Tool_Button :=
        Gtkada_Combo_Tool_Button (Button);
      Stub : Gdk_Device_Record;
      pragma Unmodified (Stub);
      Tmp : Boolean;
      pragma Unreferenced (Tmp);
   begin
      Popdown (B);

      B.Popup_Time := Event.Time;
      B.Popup_Device := Gdk_Device (Get_User_Data (Event.Device, Stub));
      Ref (B.Popup_Device);

      if Event.Button = 1 then
         if B.Popup_Timeout /= No_Source_Id then
            Remove (B.Popup_Timeout);
         end if;
         B.Popup_Timeout := Button_Sources.Timeout_Add
           (300, On_Long_Click'Access, B);

      elsif Event.Button = 3 then
         --  Immediately popup the dialog.
         --  This is a workaround for a OSX-specific bug in gtk+ 3.8.2: if we
         --  popup the dialog later, there will be not "current event" at that
         --  point, so gtk+ will be waiting for the first ENTER_NOTIFY on a
         --  GtkMenuItem before taking into account a BUTTON_RELEASE_EVENT.
         --  But because of the way the grabs are handled, that ENTER_NOTIFY
         --  is never sent/received, so we cannot select an item in the menu at
         --  all.
         --  Because of the same bug, the current item in the menu might not be
         --  highlighted in any case on OSX, but at least with an immediate
         --  popup we can properly select any of the items.

         Tmp := On_Long_Click (B);
      end if;
      return False;
   end On_Button_Press;

   -----------------------
   -- On_Button_Release --
   -----------------------

   function On_Button_Release
     (Button : access GObject_Record'Class;
      Event  : Gdk_Event_Button) return Boolean
   is
      pragma Unreferenced (Event);

      B : constant Gtkada_Combo_Tool_Button :=
        Gtkada_Combo_Tool_Button (Button);
   begin
      if B.Popup_Timeout /= No_Source_Id then
         Remove (B.Popup_Timeout);
         B.Popup_Timeout := No_Source_Id;
         --  Widget_Callback.Emit_By_Name (B, Signal_Clicked);

      else
         --  We already performed the long click, so don't do the default
         --  action in addition
         null;
      end if;

      if B.Popup_Device /= null then
         Unref (B.Popup_Device);
         B.Popup_Device := null;
      end if;

      return False;
   end On_Button_Release;

   ----------------------------
   -- On_Menu_Button_Release --
   ----------------------------

   function On_Menu_Button_Release
     (Button : access GObject_Record'Class;
      Event  : Gdk_Event_Button) return Boolean
   is
      B : constant Gtkada_Combo_Tool_Button :=
        Gtkada_Combo_Tool_Button (Button);
      Obj : GObject;
   begin
      Obj := Get_User_Data (Event.Window);
      if Obj /= null and then Obj.all in Menu_Item_Record'Class then
         B.Menu.Select_Item (Menu_Item (Obj));
      end if;

      if B.Popup_Device /= null then
         Unref (B.Popup_Device);
         B.Popup_Device := null;
      end if;

      if B.Popup_Timeout /= No_Source_Id then
         Remove (B.Popup_Timeout);
         B.Popup_Timeout := No_Source_Id;
      end if;

      --  Leave default behavior, which is to close the menu.
      return False;
   end On_Menu_Button_Release;

   -------------------
   -- On_Long_Click --
   -------------------

   function On_Long_Click (Self : Gtkada_Combo_Tool_Button) return Boolean is
   begin
      if Self.Popup_Timeout /= No_Source_Id then
         Remove (Self.Popup_Timeout);
         Self.Popup_Timeout := No_Source_Id;
      end if;

      Menu_Popup.Popup_For_Device
        (Self.Menu,
         Device            => Self.Popup_Device,
         Parent_Menu_Shell => null,
         Parent_Menu_Item  => null,
         Func              => Menu_Position'Access,
         Data              => Self,
         Button            => 1,
         Activate_Time     => Self.Popup_Time);

      Self.Menu.Select_Item (Self.Menu.Get_Active);
      return False;
   end On_Long_Click;

   -------------------
   -- Menu_Detacher --
   -------------------

   procedure Menu_Detacher
     (Attach_Widget : System.Address; Menu : System.Address)
   is
      pragma Unreferenced (Menu);
      Stub : Gtkada_Combo_Tool_Button_Record;
      pragma Unmodified (Stub);
      Self : constant Gtkada_Combo_Tool_Button :=
         Gtkada_Combo_Tool_Button (Get_User_Data (Attach_Widget, Stub));
   begin
      if Self.Menu /= null then
         Detach (Self.Menu);
      end if;
   end Menu_Detacher;

   -------------------
   -- Menu_Position --
   -------------------

   procedure Menu_Position
     (Menu    : not null access Gtk_Menu_Record'Class;
      X       : out Gint;
      Y       : out Gint;
      Push_In : out Boolean;
      Widget  : Gtkada_Combo_Tool_Button)
   is
      pragma Unreferenced (Menu);
      Menu_Req    : Gtk_Requisition;
      Allo : Gtk_Allocation;

   begin
      Size_Request (Widget.Menu, Menu_Req);
      Get_Origin (Get_Window (Widget), X, Y);
      Get_Allocation (Widget, Allo);

      X := X + Allo.X;
      Y := Y + Allo.Y + Allo.Height;

      Push_In := False;

      if Allo.Width > Menu_Req.Width then
         X := X + Allo.Width - Menu_Req.Width;
      end if;
   end Menu_Position;

   ----------------------------
   -- On_Menu_Item_Activated --
   ----------------------------

   procedure On_Menu_Item_Activated
     (Item   : access Menu_Item_Record'Class;
      Widget : Gtkada_Combo_Tool_Button)
   is
   begin
      Select_Item (Widget, Item.Label.Get_Text);
      Widget_Callback.Emit_By_Name (Widget, Signal_Clicked);
   end On_Menu_Item_Activated;

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (Self     : out Gtkada_Combo_Tool_Button;
      Stock_Id : String)
   is
   begin
      Self := new Gtkada_Combo_Tool_Button_Record;
      Initialize (Self, Stock_Id);
   end Gtk_New;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Self     : access Gtkada_Combo_Tool_Button_Record'Class;
      Stock_Id : String)
   is

   begin
      Initialize_Class_Record
        (Ancestor     => Gtk.Tool_Button.Get_Type,
         Signals      => Signals,
         Class_Record => Class_Record,
         Type_Name    => "GtkadaComboToolButton");
      Glib.Object.G_New (Self, Class_Record);

      Get_Style_Context (Self).Add_Class ("gps-combo-tool-button");

      Self.Set_Stock_Id (Stock_Id);
      Self.Set_Homogeneous (False);
      Self.Items    := Strings_Vector.Empty_Vector;
      Self.Selected := Strings_Vector.No_Index;
      Self.Stock_Id := To_Unbounded_String (Stock_Id);

      Self.Clear_Items;  --  Creates the menu

      Get_Button (Self).On_Button_Press_Event (On_Button_Press'Access, Self);
      Get_Button (Self).On_Button_Release_Event
        (On_Button_Release'Access, Self);
      Self.On_Draw (On_Draw'Access, Self, After => True);

      Self.On_Destroy (On_Destroy'Access);
   end Initialize;

   ----------------
   -- On_Destroy --
   ----------------

   procedure On_Destroy (Self : access Gtk_Widget_Record'Class) is
      S : constant Gtkada_Combo_Tool_Button := Gtkada_Combo_Tool_Button (Self);
   begin
      if S.Menu /= null then
         Unref (S.Menu);
         S.Menu := null;
      end if;
   end On_Destroy;

   --------------
   -- Add_Item --
   --------------

   procedure Add_Item
     (Widget   : access Gtkada_Combo_Tool_Button_Record;
      Item     : String;
      Stock_Id : String := "";
      Data     : User_Data := null)
   is
      First  : constant Boolean := Widget.Items.Is_Empty;
      M_Item : Menu_Item;

   begin
      if Stock_Id /= "" then
         Gtk_New (M_Item, Item, Stock_Id, Data);
      else
         Gtk_New (M_Item, Item, To_String (Widget.Stock_Id), Data);
      end if;

      Widget.Menu.Add (M_Item);
      Items_Callback.Connect
        (M_Item, Gtk.Menu_Item.Signal_Activate,
         On_Menu_Item_Activated'Access,
         Gtkada_Combo_Tool_Button (Widget));

      Widget.Items.Append (To_Unbounded_String (Item));

      if First then
         Widget.Select_Item (Item);
      end if;
   end Add_Item;

   -----------------
   -- Select_Item --
   -----------------

   procedure Select_Item
     (Widget : access Gtkada_Combo_Tool_Button_Record;
      Item   : String)
   is
      M_Item : Menu_Item;
   begin
      if Widget.Selected /= Strings_Vector.No_Index then
         --  A bit weird, but with Menu API, the only way to retrieve an item
         --  from its place number is to set it active first, then get the
         --  active menu_item ...
         Widget.Menu.Set_Active (Guint (Widget.Selected));
         Menu_Item (Widget.Menu.Get_Active).Set_Highlight (False);
      end if;

      for J in Widget.Items.First_Index .. Widget.Items.Last_Index loop
         if Widget.Items.Element (J) = Item then
            Widget.Menu.Set_Active (Guint (J));
            M_Item := Menu_Item (Widget.Menu.Get_Active);
            M_Item.Set_Highlight (True);
            Widget.Selected := J;

            --  Change the toolbar icon
            if M_Item /= null and then M_Item.Stock_Id /= "" then
               Widget.Set_Stock_Id (To_String (M_Item.Stock_Id));
            else
               Widget.Set_Stock_Id (To_String (Widget.Stock_Id));
            end if;

            Widget_Callback.Emit_By_Name (Widget, Signal_Selection_Changed);
            return;
         end if;
      end loop;
      --  ??? raise something ?
   end Select_Item;

   -----------------
   -- Clear_Items --
   -----------------

   procedure Clear_Items (Widget : access Gtkada_Combo_Tool_Button_Record) is
   begin
      Widget.Items.Clear;
      Popdown (Widget);

      if Widget.Menu /= null then
         Widget.Menu.Detach;   --  also resets menu to null
      end if;

      Gtk_New (Widget.Menu);
      Ref (Widget.Menu);
      Widget.Menu.Attach_To_Widget (Widget, Menu_Detacher'Access);

      --  This is necessary because the menu gets a grab, and on OSX we cannot
      --  select the current item from the menu (on a long click) because the
      --  Enter/Leave events have not been propagated correctly.
      Widget.Menu.On_Button_Release_Event
        (On_Menu_Button_Release'Access, Widget);
   end Clear_Items;

   -----------------------
   -- Get_Selected_Item --
   -----------------------

   function Get_Selected_Item
     (Widget : access Gtkada_Combo_Tool_Button_Record) return String
   is
      Item : constant Menu_Item := Menu_Item (Widget.Menu.Get_Active);
   begin
      if Item /= null then
         return Item.Label.Get_Text;
      else
         return "";
      end if;
   end Get_Selected_Item;

   ----------------------------
   -- Get_Selected_Item_Data --
   ----------------------------

   function Get_Selected_Item_Data
     (Widget : access Gtkada_Combo_Tool_Button_Record)
      return User_Data
   is
      Item : constant Menu_Item := Menu_Item (Widget.Menu.Get_Active);
   begin
      if Item /= null then
         return Item.Data;
      else
         return null;
      end if;
   end Get_Selected_Item_Data;

end Gtkada.Combo_Tool_Button;
