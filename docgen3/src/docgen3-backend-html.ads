------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                       Copyright (C) 2013, AdaCore                        --
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

--  This package implements a HTML backend of Docgen.

--  with Docgen3.Atree; use Docgen3.Atree;

private package Docgen3.Backend.HTML is

   type HTML_Backend is new Docgen3.Backend.Docgen3_Backend with private;

   overriding procedure Initialize
     (Self    : in out HTML_Backend;
      Context : access constant Docgen_Context);
   --  Initialize the backend and create the destination directory with support
   --  files. Returns the backend structure used to collect information of all
   --  the processed files (used to generate the global indexes).

   overriding procedure Process_File
     (Self : in out HTML_Backend;
      Tree : access Tree_Type);
   --  Generate the documentation of a single file

   overriding procedure Finalize
     (Self                : in out HTML_Backend;
      Update_Global_Index : Boolean);
   --  If Update_Global_Index is true then update the global indexes.

private

   type Collected_Entities is record
      null;
--        Access_Types     : EInfo_List.Vector;
--        CPP_Classes      : EInfo_List.Vector;
--        CPP_Constructors : EInfo_List.Vector;
--        Generic_Formals  : EInfo_List.Vector;
--        Interface_Types  : EInfo_List.Vector;
--        Methods          : EInfo_List.Vector;
--        Pkgs             : aliased EInfo_List.Vector;
--        Record_Types     : EInfo_List.Vector;
--        Simple_Types     : EInfo_List.Vector;
--        Subprgs          : aliased EInfo_List.Vector;
--        Tagged_Types     : EInfo_List.Vector;
--        Variables        : EInfo_List.Vector;
   end record;

   type HTML_Backend is new Docgen3.Backend.Docgen3_Backend with record
      Context     : access constant Docgen_Context;
      Src_Files   : Files_List.Vector;
--        Extra_Files : Files_List.Vector;
--        --  Additional files generated by the backend for nested packages
--
--        Entities    : Collected_Entities;
   end record;

end Docgen3.Backend.HTML;