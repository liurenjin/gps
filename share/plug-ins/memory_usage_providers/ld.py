import GPS
import os.path
import re
from . import core
from workflows import run_as_workflow
from workflows.promises import ProcessWrapper

MAP_FILE_BASE_NAME = "map.txt"

xml = """
<filter name="ld_supports_map_file" shell_lang="python"
        shell_cmd="memory_usage_providers.ld.LD.map_file_is_supported(
GPS.current_context())" />
"""


@core.register_memory_usage_provider("LD")
class LD(core.MemoryUsageProvider):

    _cache = {}

    @staticmethod
    def map_file_is_supported(context):
        """
        The filter used to know if the ld linker supports the '-map' switch.
        """

        target = GPS.get_target()
        build_mode = GPS.get_build_mode()

        v = LD._cache.get((target, build_mode), None)
        if v is not None:
            return v

        if not target or target == 'native' or build_mode != 'default':
            return False

        ld_exe = target + '-ld'

        try:
            process = GPS.Process([ld_exe, '--help'])
            output = process.get_result()
            v = '-map' in output
        except:
            v = False

        LD._cache[(target, build_mode)] = v

        return v

    def is_enabled(self):
        return LD.map_file_is_supported(None)

    @run_as_workflow
    def async_fetch_memory_usage_data(self, visitor):
        # Retrieve the memory map file generated by ld
        project = GPS.Project.root()
        obj_dirs = project.object_dirs(recursive=False)
        map_dir = project.file().directory() if not obj_dirs else obj_dirs[0]
        map_file_name = os.path.join(map_dir, MAP_FILE_BASE_NAME)

        # The information we want to fetch: memory regions and memory sections
        # ??? Find a way to have a finer grain view (symbols? compilation
        # units?)
        regions = []
        sections = []
        modules_dict = {}
        modules = []

        # The regexps used to match the information we want to fetch
        region_r = re.compile('^(?P<name>\w+)\s+(?P<origin>0x[0-9a-f]+)' +
                              '\s+(?P<length>0x[0-9a-f]+)\s+x?r?w?')
        section_r = re.compile('^(?P<name>[\w.]+)\s+(?P<origin>0x[0-9a-f]+)' +
                               '\s+(?P<length>0x[0-9a-f]+)')
        module_r = re.compile('^\s+[\w.]*\s+(?P<origin>0x[0-9a-f]+)\s+' +
                              '(?P<size>0x[0-9a-f]+) (?P<files>.+\.o\)?)')

        def region_name_from_address(addr):
            """
            Return the name of the region associated with the given address or
            an empty string if not found.
            """

            for region in regions:
                region_addr = int(region[1], 16)
                region_size = region[2]

                if addr >= region_addr and addr < (region_addr + region_size):
                    return region[0]

            return ""

        def try_match_region(line):
            """
            Try to match a region description in the given line.

            Return a tuple (name, origin, length) if a region was matched
            and None otherwise.
            """

            m = region_r.search(line)
            if m:
                return (m.group('name'), m.group('origin'),
                        int(m.group('length'), 16))
            else:
                return None

        def try_match_section(line):
            """
            Try to match an allocated section description in the given live.

            An allocated section is a memory section that will actually be
            loaded by the target. Sections related with debug information,
            code comments or that have null size are typically not allocated
            and should be ignored.

            Return a tuple (name, origin, length, region_name) if a section was
            matched and None otherwise.
            """

            not_alloc_sections_prefixes = ['.debug', '.comment']
            m = section_r.search(line)

            if m:
                section_addr = m.group('origin')
                region_name = region_name_from_address(int(section_addr, 16))
                section = (m.group('name'), section_addr,
                           int(m.group('length'), 16), region_name)

                for prefix in not_alloc_sections_prefixes:
                    if section[0].startswith(prefix):
                        return None

                if section[2] == 0:
                    return None

                return section
            else:
                return None

        def try_match_module(line):
            """
            Try to match a module description in the given line.

            A module description gives information about the size taken by
            an object file in a given section.
            """

            m = module_r.search(line)
            if m:
                files_info = m.group('files')
                files = re.split("\(|\)", files_info)

                # Get the object file name and, if any, information about
                # the library for which this file has been compiled.

                obj_file = files[0] if len(files) == 1 else files[1]
                lib_file = files[0] if len(files) > 1 else ""

                section = sections[-1]
                section_name = section[0]
                module = modules_dict.get((files_info, section_name), None)

                # If the object file name does not contain any directory
                # information assume that this file is located in the same
                # directory as the map file.

                if not os.path.dirname(obj_file) and not lib_file:
                    obj_file = os.path.join(map_dir, obj_file)

                # If a previous module decription has been found for the same
                # key, just add the size of this one to the previously found
                # one.

                if module:
                    module[3] += int(m.group('size'), 16)
                else:
                    region_name = section[3]
                    module = [obj_file, lib_file, m.group('origin'),
                              int(m.group('size'), 16),
                              region_name, section_name]
                    modules_dict[(files_info, section_name)] = module

        # Parse the memory map file to retrieve the memory regions and
        # the path of the linked executable.

        with open(map_file_name, 'r') as f:
            for line in f:
                region = try_match_region(line)
                if not region:
                    section = try_match_section(line)
                    if section:
                        sections.append(section)
                    else:
                        try_match_module(line)
                else:
                    regions.append(region)

        for module in modules_dict.itervalues():
            modules.append(tuple(module))

        visitor.on_memory_usage_data_fetched(regions, sections, modules)

GPS.parse_xml(xml)