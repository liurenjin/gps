------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2001-2013, AdaCore                     --
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

with Gtk.Text_Tag; use Gtk.Text_Tag;
with Glib.Properties;

package body Src_Editor_Buffer.Multi_Cursors is

   Mc_Selection_Tag : constant String := "mc_selection";

   procedure Check_Mc_Selection_Tag (Buffer : Source_Buffer);

   -----------------------------
   -- Create_Mc_Selection_Tag --
   -----------------------------

   procedure Check_Mc_Selection_Tag (Buffer : Source_Buffer) is
      T : Gtk_Text_Tag := Buffer.Get_Tag_Table.Lookup (Mc_Selection_Tag);
   begin
      if T = null then
         T := Buffer.Create_Tag (Mc_Selection_Tag);
      end if;
      Glib.Properties.Set_Property (T, Background_Property, "green");
   end Check_Mc_Selection_Tag;

   ------------
   -- Create --
   ------------

   function Create
     (C : Multi_Cursor_Access; Buffer : Source_Buffer) return Cursor
   is
     ((Cursor    => C,
       Cursor_Id => C.Id,
       Buffer    => Buffer));

   --------------
   -- Is_Alive --
   --------------

   function Is_Alive (C : Cursor) return Boolean is
     (C.Cursor_Id > C.Buffer.Multi_Cursors_Last_Alive_Id);

   -------------------------
   -- Update_MC_Selection --
   -------------------------

   procedure Update_MC_Selection (B : Source_Buffer) is
      Start_Loc, End_Loc : Gtk_Text_Iter;
      T : Gtk_Text_Tag;
      Line : Editable_Line_Type;
      Col  : Character_Offset_Type;
   begin
      Check_Mc_Selection_Tag (B);
      T := B.Get_Tag_Table.Lookup (Mc_Selection_Tag);
      B.Get_Start_Iter (Start_Loc);
      B.Get_End_Iter (End_Loc);
      B.Remove_Tag (T, Start_Loc, End_Loc);

      for C of B.Multi_Cursors_List loop
         B.Get_Iter_At_Mark (Start_Loc, C.Sel_Mark);
         B.Get_Iter_At_Mark (End_Loc, C.Mark);

         Get_Iter_Position (B, End_Loc, Line, Col);

         B.Apply_Tag (T, Start_Loc, End_Loc);
      end loop;
   end Update_MC_Selection;

   --------------
   -- Get_Mark --
   --------------

   function Get_Mark (C : Cursor) return Gtk_Text_Mark
   is (C.Cursor.Mark);

   -----------------------
   -- Get_Sel_Mark_Name --
   -----------------------

   function Get_Sel_Mark_Name (Cursor_Mark_Name : String) return String
   is
     (Cursor_Mark_Name & "_sel");

   ------------------
   -- Get_Sel_Mark --
   ------------------

   function Get_Sel_Mark (C : Cursor) return Gtk_Text_Mark
   is (C.Cursor.Sel_Mark);

   -----------------------
   -- Get_Column_Memory --
   -----------------------

   function Get_Column_Memory (C : Cursor) return Gint
   is (C.Cursor.Column_Memory);

   -----------------------
   -- Set_Column_Memory --
   -----------------------

   procedure Set_Column_Memory (C : Cursor; Offset : Gint) is
   begin
      C.Cursor.Column_Memory := Offset;
   end Set_Column_Memory;

   ----------------------
   -- Add_Multi_Cursor --
   ----------------------

   procedure Add_Multi_Cursor
     (Buffer : Source_Buffer; Location : Gtk_Text_Iter) is

      Cursor_Name : constant String :=
        "multi_cursor_" & Buffer.Multi_Cursors_Next_Id'Img;
      Cursor_Mark : constant Gtk_Text_Mark := Gtk_Text_Mark_New
        (Cursor_Name, False);
      Sel_Mark : constant Gtk_Text_Mark := Gtk_Text_Mark_New
        (Get_Sel_Mark_Name (Cursor_Name), False);
   begin
      Check_Mc_Selection_Tag (Buffer);

      Buffer.Multi_Cursors_List.Append
        ((Id              => Buffer.Multi_Cursors_Next_Id,
          Mark            => Cursor_Mark,
          Sel_Mark        => Sel_Mark,
          Current_Command => null,
          Column_Memory   => Get_Offset (Location),
          Clipboard       => <>));

      Buffer.Add_Mark (Cursor_Mark, Location);
      Buffer.Add_Mark (Sel_Mark, Location);
      Buffer.Multi_Cursors_Next_Id := Buffer.Multi_Cursors_Next_Id + 1;
      Cursor_Mark.Set_Visible (True);
   end Add_Multi_Cursor;

   ----------------------
   -- Add_Multi_Cursor --
   ----------------------

   function Add_Multi_Cursor
     (Buffer : Source_Buffer; Location : Gtk_Text_Iter) return Cursor
   is
   begin
      Add_Multi_Cursor (Buffer, Location);
      declare
         Last_El : constant Multi_Cursors_Lists.Cursor :=
           Buffer.Multi_Cursors_List.Last;
      begin
         return Create
           (Buffer.Multi_Cursors_List.Reference (Last_El).Element, Buffer);
      end;
   end Add_Multi_Cursor;

   ------------------------------
   -- Remove_All_Multi_Cursors --
   ------------------------------

   procedure Remove_All_Multi_Cursors (Buffer : Source_Buffer) is
   begin
      for Cursor of Buffer.Multi_Cursors_List loop
         if Cursor.Id > Buffer.Multi_Cursors_Last_Alive_Id then
            Buffer.Multi_Cursors_Last_Alive_Id := Cursor.Id;
         end if;

         Buffer.Delete_Mark (Cursor.Mark);
         Buffer.Delete_Mark (Cursor.Sel_Mark);
      end loop;

      Buffer.Has_MC_Clipboard := False;
      Buffer.Multi_Cursors_List.Clear;
   end Remove_All_Multi_Cursors;

   -----------------------------------
   -- Set_Multi_Cursors_Manual_Sync --
   -----------------------------------

   procedure Set_Multi_Cursors_Manual_Sync (Buffer : Source_Buffer)
   is
   begin
      Buffer.Multi_Cursors_Sync := (Mode => Manual_Master);
   end Set_Multi_Cursors_Manual_Sync;

   -----------------------------------
   -- Set_Multi_Cursors_Manual_Sync --
   -----------------------------------

   procedure Set_Multi_Cursors_Manual_Sync
     (C : Cursor)
   is
      MC : constant Multi_Cursor_Access := C.Cursor;
   begin
      C.Buffer.Multi_Cursors_Sync :=
        (Manual_Slave, MC);
   end Set_Multi_Cursors_Manual_Sync;

   -----------------------------------
   -- Set_Multi_Cursors_Manual_Sync --
   -----------------------------------

   procedure Set_Multi_Cursors_Manual_Sync
     (Buffer : Source_Buffer;
      MC     : Multi_Cursor_Access)
   is
   begin
      Buffer.Multi_Cursors_Sync :=
        (Manual_Slave, MC);
   end Set_Multi_Cursors_Manual_Sync;

   ---------------------------------
   -- Set_Multi_Cursors_Auto_Sync --
   ---------------------------------

   procedure Set_Multi_Cursors_Auto_Sync (Buffer : Source_Buffer)
   is
   begin
      Buffer.Multi_Cursors_Sync := (Mode => Auto);
   end Set_Multi_Cursors_Auto_Sync;

   function Get_Multi_Cursors
     (Buffer : Source_Buffer) return Cursors_Lists.List
   is
      package L renames Multi_Cursors_Lists;
      C : L.Cursor;
   begin
      return List : Cursors_Lists.List do
         C := Buffer.Multi_Cursors_List.First;
         while L.Has_Element (C) loop
            List.Append
              (Create
                 (Buffer.Multi_Cursors_List.Reference (C).Element, Buffer));
            C := L.Next (C);
         end loop;
      end return;
   end Get_Multi_Cursors;

   ----------------------------
   -- Get_Multi_Cursors_Sync --
   ----------------------------

   function Get_Multi_Cursors_Sync
     (Buffer : Source_Buffer) return Multi_Cursors_Sync_Type
   is (Buffer.Multi_Cursors_Sync);

   ----------------------------
   -- Set_Multi_Cursors_Sync --
   ----------------------------

   procedure Set_Multi_Cursors_Sync
     (Buffer : Source_Buffer; Sync : Multi_Cursors_Sync_Type)
   is
   begin
      Buffer.Multi_Cursors_Sync := Sync;
   end Set_Multi_Cursors_Sync;

end Src_Editor_Buffer.Multi_Cursors;
