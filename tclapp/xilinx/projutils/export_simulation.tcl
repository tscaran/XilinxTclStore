####################################################################################
#
# export_simulation.tcl
#
# Script created on 07/12/2013 by Raj Klair (Xilinx, Inc.)
#
####################################################################################
package require Vivado 1.2014.1
package require struct::matrix

namespace eval ::tclapp::xilinx::projutils {
  namespace export export_simulation
}

namespace eval ::tclapp::xilinx::projutils {
proc export_simulation {args} {
  # Summary:
  # Export a script and associated data files (if any) for driving standalone simulation using the specified simulator.
  # Argument Usage:
  # [-simulator <arg> = all]: Simulator for which the simulation script will be created (value=all|xsim|modelsim|questa|ies|vcs)
  # [-language <arg> = mixed]: simulator language (value=mixed|verilog|vhdl)
  # [-of_objects <arg> = None]: Export simulation script for the specified object
  # [-lib_map_path <arg> = Empty]: Precompiled simulation library directory path. If not specified, then please follow the instructions in the generated script header to manually provide the simulation library mapping information.
  # [-script_name <arg> = top_module.sh/.bat]: Output shell script filename. If not specified, then file with a default name will be created.
  # [-directory <arg> = export_sim]: Directory where the simulation script will be exported
  # [-runtime <arg> = Empty]: Run simulation for this time (default:full simulation run or until a logical break or finish condition)
  # [-absolute_path]: Make all file paths absolute wrt the reference directory
  # [-single_step]: Generate script to launch all steps in one step
  # [-ip_netlist]: Select the netlist file for IP(s) in the project or the selected object (-of_objects) for the specified simulator language (default:verilog)
  # [-export_source_files]: Copy design files to output directory
  # [-32bit]: Perform 32bit compilation
  # [-force]: Overwrite previous files

  # Return Value:
  # None

  # Categories: simulation, xilinxtclstore

  if { ![get_param "project.enableExportSimulation"] } {
    send_msg_id exportsim-Tcl-001 INFO \
      "This command is not available in the current release of Vivado and will be enhanced for future releases of Vivado to support all simulators, please contact Xilinx (FAE, tech support or forum) for more information.\n"
    return
  }

  variable a_sim_vars
  xps_init_vars
  set a_sim_vars(options) [split $args " "]

  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-of_objects"               { incr i;set a_sim_vars(sp_of_objects) [lindex $args $i];set a_sim_vars(b_of_objects_specified) 1 }
      "-32bit"                    { set a_sim_vars(b_32bit) 1 }
      "-absolute_path"            { set a_sim_vars(b_absolute_path) 1 }
      "-single_step"              { set a_sim_vars(b_single_step) 1 }
      "-language"                 { incr i;set a_sim_vars(s_simulator_language) [string tolower [lindex $args $i]];set a_sim_vars(b_simulator_language) 1 }
      "-ip_netlist"               { set a_sim_vars(b_ip_netlist) 1 }
      "-export_source_files"      { set a_sim_vars(b_xport_src_files) 1 }
      "-lib_map_path"             { incr i;set a_sim_vars(s_lib_map_path) [lindex $args $i] }
      "-script_name"              { incr i;set a_sim_vars(s_script_filename) [lindex $args $i];set a_sim_vars(b_script_specified) 1 }
      "-force"                    { set a_sim_vars(b_overwrite) 1 }
      "-simulator"                { incr i;set a_sim_vars(s_simulator) [string tolower [lindex $args $i]] }
      "-directory"                { incr i;set a_sim_vars(s_xport_dir) [lindex $args $i];set a_sim_vars(b_directory_specified) 1 }
      "-runtime"                  { incr i;set a_sim_vars(s_runtime) [lindex $args $i];set a_sim_vars(b_runtime_specified) 1 }
      default {
        if { [regexp {^-} $option] } {
          send_msg_id exportsim-Tcl-003 ERROR "Unknown option '$option', please type 'export_simulation -help' for usage info.\n"
          return
        }
      }
    }
  }
  if { [xps_invalid_options] } {
    return
  }


  xps_set_target_simulator

  set objs $a_sim_vars(sp_of_objects)
  if { $a_sim_vars(b_of_objects_specified) && ({} == $objs) } {
    send_msg_id exportsim-Tcl-000 INFO "No objects found specified with the -of_objects switch.\n"
    return
  }

  # no -of_objects specified
  if { ({} == $objs) || ([llength $objs] == 1) } {
    if { [xps_xport_simulation $objs] } {
      return
    }
  } else {
    foreach obj $objs {
      if { [xps_xport_simulation $obj] } {
        continue
      }
    }
  }
  return
}
}

namespace eval ::tclapp::xilinx::projutils {
proc xps_init_vars {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set a_sim_vars(curr_time)           [clock format [clock seconds]]
  set a_sim_vars(s_simulator)         "all"
  set a_sim_vars(s_xport_dir)         "export_sim"
  set a_sim_vars(s_simulator_name)    ""
  set a_sim_vars(b_xsim_specified)    0
  set a_sim_vars(s_lib_map_path)      ""
  set a_sim_vars(b_script_specified)  0
  set a_sim_vars(s_script_filename)   ""
  set a_sim_vars(s_runtime)           ""
  set a_sim_vars(b_runtime_specified) 0
  set a_sim_vars(s_simulator_language) "mixed"
  set a_sim_vars(s_ip_netlist)        "verilog"
  set a_sim_vars(b_ip_netlist)        0
  set a_sim_vars(b_simulator_language) 0
  set a_sim_vars(ip_filename)         ""
  set a_sim_vars(s_ip_file_extn)      ".xci"
  set a_sim_vars(b_extract_ip_sim_files) 0
  set a_sim_vars(b_32bit)             0
  set a_sim_vars(sp_of_objects)       {}
  set a_sim_vars(b_is_ip_object_specified)      0
  set a_sim_vars(b_is_fs_object_specified)      0
  set a_sim_vars(b_absolute_path)     0             
  set a_sim_vars(b_single_step)       0             
  set a_sim_vars(b_xport_src_files)   0             
  set a_sim_vars(b_overwrite)         0
  set a_sim_vars(b_of_objects_specified)        0
  set a_sim_vars(b_directory_specified)         0
  set a_sim_vars(fs_obj)              [current_fileset -simset]
  set a_sim_vars(sp_tcl_obj)          ""
  set a_sim_vars(s_top)               ""
  set a_sim_vars(b_is_managed)        [get_property managed_ip [current_project]]
  set a_sim_vars(s_install_path)      {}
  set a_sim_vars(b_scripts_only)      0
  set a_sim_vars(global_files_str)    {}
  set a_sim_vars(default_lib)         [get_property default_lib [current_project]]
  set a_sim_vars(do_filename)         "simulate.do"
  set a_sim_vars(dynamic_repo_dir)    [get_property ip.user_files_dir [current_project]]
  set a_sim_vars(ipstatic_dir)        [get_property sim.ipstatic.source_dir [current_project]]
  set a_sim_vars(b_use_static_lib)    [get_property sim.ipstatic.use_precompiled_libs [current_project]]

  variable l_compile_order_files      [list]
  variable l_design_files             [list]

  # ip static libraries
  variable l_ip_static_libs           [list]
  variable l_simulators               [list xsim modelsim questa ies vcs]
  variable l_target_simulator         [list]

  variable l_valid_simulator_types    [list]
  set l_valid_simulator_types         [list all xsim modelsim questa ies vcs vcs_mx ncsim]
  variable l_valid_ip_netlist_types   [list]
  set l_valid_ip_netlist_types        [list verilog vhdl]
  variable l_valid_simulator_language_types   [list]
  set l_valid_simulator_language_types        [list mixed verilog vhdl]
  variable l_valid_ip_extns           [list]
  set l_valid_ip_extns                [list ".xci" ".bd" ".slx"]
  variable s_data_files_filter
  set s_data_files_filter             "FILE_TYPE == \"Data Files\" || FILE_TYPE == \"Memory Initialization Files\" || FILE_TYPE == \"Coefficient Files\""
  variable s_embedded_files_filter
  set s_embedded_files_filter         "FILE_TYPE == \"BMM\" || FILE_TYPE == \"ElF\""
  variable s_non_hdl_data_files_filter
  set s_non_hdl_data_files_filter \
               "FILE_TYPE != \"Verilog\"                      && \
                FILE_TYPE != \"SystemVerilog\"                && \
                FILE_TYPE != \"Verilog Header\"               && \
                FILE_TYPE != \"Verilog Template\"             && \
                FILE_TYPE != \"VHDL\"                         && \
                FILE_TYPE != \"VHDL 2008\"                    && \
                FILE_TYPE != \"VHDL Template\"                && \
                FILE_TYPE != \"EDIF\"                         && \
                FILE_TYPE != \"NGC\"                          && \
                FILE_TYPE != \"IP\"                           && \
                FILE_TYPE != \"XCF\"                          && \
                FILE_TYPE != \"NCF\"                          && \
                FILE_TYPE != \"UCF\"                          && \
                FILE_TYPE != \"XDC\"                          && \
                FILE_TYPE != \"NGO\"                          && \
                FILE_TYPE != \"Waveform Configuration File\"  && \
                FILE_TYPE != \"BMM\"                          && \
                FILE_TYPE != \"ELF\"                          && \
                FILE_TYPE != \"Design Checkpoint\""
}
}

namespace eval ::tclapp::xilinx::projutils {

proc xps_set_target_simulator {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_simulators
  variable l_target_simulator
  if { {all} == $a_sim_vars(s_simulator) } {
    foreach simulator $l_simulators {
      lappend l_target_simulator $simulator
    }
  } else {
    if { {vcs_mx} == $a_sim_vars(s_simulator) } {
      set $a_sim_vars(s_simulator) "vcs"
    }
    if { {ncsim} == $a_sim_vars(s_simulator) } {
      set $a_sim_vars(s_simulator) "ies"
    }
    lappend l_target_simulator $a_sim_vars(s_simulator)
  }

  if { ([llength $l_target_simulator] == 1) && ({xsim} == [lindex $l_target_simulator 0]) } {
    set a_sim_vars(b_xsim_specified) 1
  }
}

proc xps_xport_simulation { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  if { [xps_set_target_obj $obj] } {
    return 1
  }

  set xport_dir [file normalize [string map {\\ /} $a_sim_vars(s_xport_dir)]]
  set run_dir {}
  if { [xps_create_rundir $xport_dir run_dir] } {
    return 1
  }

  # main readme
  xps_readme $run_dir
  xps_extract_ip_files
  xps_xtract_ips
  if { ([lsearch $a_sim_vars(options) {-of_objects}] != -1) && ([llength $a_sim_vars(sp_tcl_obj)] == 0) } {
    send_msg_id exportsim-Tcl-006 ERROR "Invalid object specified. The object does not exist.\n"
    return 1
  }


  set data_files [list]
  xps_xport_data_files data_files
  xps_set_script_filename

  set filename ${a_sim_vars(s_script_filename)}.sh

  if { [xps_write_sim_script $run_dir $data_files $filename] } { return }

  set readme_file [file join $run_dir "README.txt"]
  #send_msg_id exportsim-Tcl-030 INFO \
  #  "Please see readme file for instructions on how to use the generated script: '$readme_file'\n"

  return 0
}

proc xps_invalid_options {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_valid_simulator_types
  variable l_valid_ip_netlist_types
  variable l_valid_simulator_language_types
  if { {} != $a_sim_vars(s_script_filename) } {
    set extn [string tolower [file extension $a_sim_vars(s_script_filename)]]
    if { ({.sh} != $extn) } {
      [catch {send_msg_id exportsim-Tcl-004 ERROR "Invalid script file extension '$extn' specified. Please provide script filename with the '.sh' extension.\n"} err]
      return 1
    }
  }

  if { [lsearch -exact $l_valid_simulator_types $a_sim_vars(s_simulator)] == -1 } {
    [catch {send_msg_id exportsim-Tcl-004 ERROR "Invalid simulator type specified. Please type 'export_simulation -help' for usage info.\n"} err]
    return 1
  }

  if { $a_sim_vars(b_simulator_language) } {
    if { [lsearch -exact $l_valid_simulator_language_types $a_sim_vars(s_simulator_language)] == -1 } {
      [catch {send_msg_id exportsim-Tcl-005 ERROR "Invalid simulator language type specified. Please type 'export_simulation -help' for usage info.\n"} err]
      return 1
    }

    set a_sim_vars(s_ip_netlist) $a_sim_vars(s_simulator_language)
  }

  if { $a_sim_vars(b_single_step) && ([string length $a_sim_vars(s_lib_map_path)] > 0) } {
    switch $a_sim_vars(s_simulator) {
      "questa" -
      "ies" -
      "vcs" {
        send_msg_id exportsim-Tcl-007 WARNING \
          "The '-lib_map_path' switch is not applicable for single-step flow. In single-step flow, the simulation library will be compiled automatically by the generated script.\n"
       }
    }
  }

  switch $a_sim_vars(s_simulator) {
    "questa" -
    "vcs" {
      if { $a_sim_vars(b_ip_netlist) } {
        if { ($a_sim_vars(b_single_step)) && ({vhdl} == $a_sim_vars(s_ip_netlist)) } {
          [catch {send_msg_id exportsim-Tcl-007 ERROR "Single step simulation flow is not applicable for IP's containing VHDL netlist. Please select Verilog netlist for this simulator.\n"} err]
          return 1
        }
      }
    }
  }
  return 0
}

proc xps_extract_ip_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  variable l_target_simulator
  if { $a_sim_vars(b_xsim_specified) } {
    return
  }

  if { [get_param project.enableCentralSimRepo] } {
    set ips [get_ips -all -quiet]
    if { [llength $ips] > 0 } {
      # TODO: this is causing zip_exception
      #populate_sim_repo -of_objects $ips
    }
    return
  }

  if { ![get_property corecontainer.enable [current_project]] } {
    return
  } else {
    # auto set if core-container is on
    set_property extract_ip_sim_files true [current_project]
  }
 
  set a_sim_vars(b_extract_ip_sim_files) [get_property extract_ip_sim_files [current_project]]

  if { $a_sim_vars(b_extract_ip_sim_files) } {
    foreach ip [get_ips -all -quiet] {
      set xci_ip_name "${ip}.xci"
      set xcix_ip_name "${ip}.xcix"
      set xcix_file_path [get_property core_container [get_files -quiet -all ${xci_ip_name}]] 
      if { {} != $xcix_file_path } {
        [catch {rdi::extract_ip_sim_files -of_objects [get_files -quiet -all ${xcix_ip_name}]} err]
      }
    }
  }
}

proc xps_xtract_ips {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  if { $a_sim_vars(b_xport_src_files) } {
    foreach ip [get_ips -all -quiet] {
      set xci_ip_name "${ip}.xci"
      set xcix_ip_name "${ip}.xcix"
      set xcix_file_path [get_property core_container [get_files -quiet -all ${xci_ip_name}]] 
      if { {} != $xcix_file_path } {
        [catch {rdi::extract_ip_sim_files -quiet -of_objects [get_files -quiet -all ${xcix_ip_name}]} err]
      }
    }
  }
}

proc xps_invalid_flow_options { simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  switch $simulator {
    "questa" -
    "vcs" {
      if { ($a_sim_vars(b_single_step)) && ([xps_contains_vhdl]) } {
        send_msg_id exportsim-Tcl-008 ERROR \
          "Design contains VHDL sources. The single step simulation flow is not applicable for '$simulator' simulator. Please remove the '-single_step' switch and try again.\n"
        return 1
      }
    }
  }
  return 0
}

proc xps_create_rundir { dir run_dir_arg } {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:
 
  variable a_sim_vars
  variable l_target_simulator
  upvar $run_dir_arg run_dir
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xps_is_ip $tcl_obj] } {
    if { $a_sim_vars(b_directory_specified) } {
      set ip_dir [file tail [file dirname $tcl_obj]]
      #append ip_dir "_sim"
      set dir [file normalize [file join $dir $ip_dir]]
    } else {
      set ip_dir [file dirname $tcl_obj]
      set ip_filename [file tail $tcl_obj]
      set dir [file normalize [string map {\\ /} $ip_dir]]
      append dir "_sim"
    }
  }
  if { ! [file exists $dir] } {
    if {[catch {file mkdir $dir} error_msg] } {
      send_msg_id exportsim-Tcl-009 ERROR "failed to create the directory ($dir): $error_msg\n"
      return 1
    }
  }
  if { {all} == $a_sim_vars(s_simulator) } {
    foreach simulator $l_target_simulator {
      set sim_dir [file join $dir $simulator]
      if { [xps_create_dir $sim_dir] } {
        return 1
      }
    }
  } else {
    set sim_dir [file join $dir $a_sim_vars(s_simulator)]
    if { [xps_create_dir $sim_dir] } {
      return 1
    }
  }
  set run_dir $dir
  return 0
}

proc xps_readme { dir } {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:

  variable a_sim_vars
  set fh 0
  set filename "README.txt"
  set file [file join $dir $filename]
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-030 ERROR "failed to open file to write ($file)\n"
    return 1
  }
  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 2]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]

  puts $fh "################################################################################"
  puts $fh "# $product (TM) $version_id\n#"
  puts $fh "# $filename: Please read the sections below to understand the steps required"
  puts $fh "#             to simulate the design for a simulator, the directory structure"
  puts $fh "#             and the generated exported files.\n#"
  puts $fh "################################################################################\n"
  puts $fh "1. Simulate Design\n"
  puts $fh "To simulate design, cd to the simulator directory and execute the script.\n"
  puts $fh "For example:-\n"
  puts $fh "% cd questa"
  set extn ".bat"
  set lib_path "c:\\design\\questa\\clibs"
  set sep "\\"
  set drive {c:}
  set extn ".sh"
  set lib_path "/design/questa/clibs"
  set sep "/"
  set drive {}
  puts $fh "% ./top$extn\n"
  puts $fh "The export simulation flow requires the Xilinx pre-compiled simulation library"
  puts $fh "components for the target simulator. These components are referred using the"
  puts $fh "'-lib_map_path' switch. If this switch is specified, then the export simulation"
  puts $fh "will automatically set this library path in the generated script and update,"
  puts $fh "copy the simulator setup file(s) in the exported directory.\n"
  puts $fh "If '-lib_map_path' is not specified, then the pre-compiled simulation library"
  puts $fh "information will not be included in the exported scripts and that may cause"
  puts $fh "simulation errors when running this script. Alternatively, you can provide the"
  puts $fh "library information using this switch while executing the generated script.\n"
  puts $fh "For example:-\n"
  puts $fh "% ./top$extn -lib_map_path $lib_path\n"
  puts $fh "Please refer to the generated script header 'Prerequisite' section for more details.\n"
  puts $fh "2. Directory Structure\n"
  puts $fh "By default, if the -directory switch is not specified, export_simulation will"
  puts $fh "create the following directory structure:-\n"
  puts $fh "<current_working_directory>${sep}export_sim${sep}<simulator>\n"
  puts $fh "For example, if the current working directory is $drive${sep}tmp${sep}test, export_simulation"
  puts $fh "will create the following directory path:-\n"
  puts $fh "$drive${sep}tmp${sep}test${sep}export_sim${sep}questa\n"
  puts $fh "If -directory switch is specified, export_simulation will create a simulator"
  puts $fh "sub-directory under the specified directory path.\n"
  puts $fh "For example, 'export_simulation -directory $drive${sep}tmp${sep}test${sep}my_test_area${sep}func_sim'"
  puts $fh "command will create the following directory:-\n"
  puts $fh "$drive${sep}tmp${sep}test${sep}my_test_area${sep}func_sim${sep}questa\n"
  puts $fh "By default, if -simulator is not specified, export_simulation will create a"
  puts $fh "simulator sub-directory for each simulator and export the files for each simulator"
  puts $fh "in this sub-directory respectively.\n"
  puts $fh "IMPORTANT: Please note that the simulation library path must be specified manually"
  puts $fh "in the generated script for the respective simulator. Please refer to the generated"
  puts $fh "script header 'Prerequisite' section for more details.\n"
  puts $fh "3. Exported script and files\n"
  puts $fh "Export simulation will create the driver shell script, setup files and copy the"
  puts $fh "design sources in the output directory path.\n"
  puts $fh "By default, when the -script_name switch is not specified, export_simulation will"
  puts $fh "create the following script name:-\n"
  puts $fh "<simulation_top>.sh  (Unix)"
  puts $fh "When exporting the files for an IP using the -of_objects switch, export_simulation"
  puts $fh "will create the following script name:-\n"
  puts $fh "<ip-name>.sh  (Unix)"
  puts $fh "Export simulation will create the setup files for the target simulator specified"
  puts $fh "with the -simulator switch.\n"
  puts $fh "For example, if the target simulator is \"ies\", export_simulation will create the"
  puts $fh "'cds.lib', 'hdl.var' and design library diectories and mappings in the 'cds.lib'"
  puts $fh "file.\n"

  close $fh
}

proc xps_write_simulator_readme { dir } {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:

  variable a_sim_vars
  set fh 0
  set filename "README.txt"
  set file [file join $dir $filename]
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-030 ERROR "failed to open file to write ($file)\n"
    return 1
  }
  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 2]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]
  set extn ".sh"
  set scr_name $a_sim_vars(s_script_filename)$extn
  puts $fh "################################################################################"
  puts $fh "# $product (TM) $version_id\n#"
  puts $fh "# $filename: Please read the sections below to understand the steps required to"
  puts $fh "#             run the exported script and information about the source files.\n#"
  puts $fh "# Generated by export_simulation on $a_sim_vars(curr_time)\n#"
  puts $fh "################################################################################\n"
  puts $fh "1. How to run the script:-\n"
  puts $fh "From the shell prompt in the current directory, issue the following command:-\n"
  puts $fh "./${scr_name}\n"
  if { $a_sim_vars(b_single_step) } {
    puts $fh "This command will launch the 'execute' function implemented in the script file"
    puts $fh "for the single-step flow. This function is called from the main 'run' function"
    puts $fh "in the script file."
  } else {
    puts $fh "This command will launch the 'compile', 'elaborate' and 'simulate' functions"
    puts $fh "implemented in the script file for the 3-step flow. These functions are called"
    puts $fh "from the main 'run' function in the script file."
  }
  puts $fh "\nThe 'run' function first executes 'setup' function the purpose of which is to"
  puts $fh "create simulator specific setup files, create design library mappings and library"
  puts $fh "directories and copy 'glbl.v' from the Vivado software install location into the"
  puts $fh "current directory.\n"
  puts $fh "The 'setup' function is also used for removing the simulator generated data in"
  puts $fh "order to reset the current directory to the original state when export_simulation"
  puts $fh "was launched. This generated data can be removed by specifying the '-reset_run'"
  puts $fh "switch to the './${scr_name}' script.\n"
  puts $fh "./${scr_name} -reset_run\n"
  puts $fh "To keep the generated data from the previous run but regenerate the setup files"
  puts $fh "and library directories, use the -noclean_files switch.\n"
  puts $fh "./${scr_name} -noclean_files\n"
  puts $fh "For more information on the script, please type './${scr_name} -help'.\n"
  puts $fh "2. Additional design information files:-\n"
  puts $fh "export_simulation generates following additional files that can be used for"
  puts $fh "fetching the design files information or for integrating with external custom"
  puts $fh "scripts.\n"
  puts $fh "Name   : filelist.f"
  puts $fh "Purpose: This file contains a flat list of design files based on the compile"
  puts $fh "         order when export_simulation was executed. By default, the source file"
  puts $fh "         paths are set relative to the current directory. If -absolute_path"
  puts $fh "         switch was specified with export_simulation, then the file paths will"
  puts $fh "         be set absolute.\n"
  puts $fh "Name   : file_info.txt"
  puts $fh "Purpose: This file contains detail design file information based on the compile"
  puts $fh "         order when export_simulation was executed. The file contains information"
  puts $fh "         about the file type, name, whether belongs to IP, associated library and"
  puts $fh "         the file path."

  close $fh
  return 0
}

proc xps_create_dir { dir } {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:

  if { [file exists $dir] } {
    #set files [glob -nocomplain -directory $dir *]
    #foreach file_path $files {
    #  if {[catch {file delete -force $file_path} error_msg] } {
    #    send_msg_id exportsim-Tcl-010 ERROR "failed to delete file ($file_path): $error_msg\n"
    #    return 1
    #  }
    #}
  } else {
    if {[catch {file mkdir $dir} error_msg] } {
      send_msg_id exportsim-Tcl-011 ERROR "failed to create the directory ($dir): $error_msg\n"
      return 1
    }
  }
  return 0
}

proc xps_create_srcs_dir { dir } {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:
  
  variable a_sim_vars
  set srcs_dir {}
  if { $a_sim_vars(b_xport_src_files) } {
    set srcs_dir [file normalize [file join $dir "srcs"]]
    if {[catch {file mkdir $srcs_dir} error_msg] } {
      send_msg_id exportsim-Tcl-012 ERROR "failed to create the directory ($srcs_dir): $error_msg\n"
      return 1
    }
    set incl_dir [file normalize [file join $srcs_dir "incl"]]
    if {[catch {file mkdir $incl_dir} error_msg] } {
      send_msg_id exportsim-Tcl-013 ERROR "failed to create the directory ($incl_dir): $error_msg\n"
      return 1
    }
  }
  return $srcs_dir
}

proc xps_get_simulator_pretty_name { name } {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:
 
  set pretty_name {}
  switch -regexp -- $name {
    "xsim"     { set pretty_name "Xilinx Vivado Simulator" }
    "modelsim" { set pretty_name "Mentor Graphics ModelSim Simulator" }
    "questa"   { set pretty_name "Mentor Graphics Questa Advanced Simulator" }
    "ies"      { set pretty_name "Cadence Incisive Enterprise Simulator" }
    "vcs"      { set pretty_name "Synopsys Verilog Compiler Simulator" }
  }
  return $pretty_name
}

proc xps_set_target_obj { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_valid_ip_extns
  set a_sim_vars(b_is_ip_object_specified) 0
  set a_sim_vars(b_is_fs_object_specified) 0
  if { {} != $obj } {
    set a_sim_vars(b_is_ip_object_specified) [xps_is_ip $obj]
    set a_sim_vars(b_is_fs_object_specified) [xps_is_fileset $obj]
  }
  if { {1} == $a_sim_vars(b_is_ip_object_specified) } {
    set comp_file $obj
    set file_extn [file extension $comp_file]
    if { [lsearch -exact $l_valid_ip_extns ${file_extn}] == -1 } {
      # valid extention not found, set default (.xci)
      set comp_file ${comp_file}$a_sim_vars(s_ip_file_extn)
    } else {
      set a_sim_vars(s_ip_file_extn) $file_extn
    }
    set a_sim_vars(sp_tcl_obj) [get_files -all -quiet [list "$comp_file"]]
    set a_sim_vars(s_top) [file root [file tail $a_sim_vars(sp_tcl_obj)]]
    xps_verify_ip_status
  } else {
    if { $a_sim_vars(b_is_managed) } {
      set ips [get_ips -all -quiet]
      if {[llength $ips] == 0} {
        send_msg_id exportsim-Tcl-014 INFO "No IP's found in the current project.\n"
        return 1
      }
      [catch {send_msg_id exportsim-Tcl-015 ERROR "No IP source object specified. Please type 'export_simulation -help' for usage info.\n"} err]
      return 1
    } else {
      if { $a_sim_vars(b_is_fs_object_specified) } {
        set fs_type [get_property fileset_type [get_filesets $obj]]
        set fs_of_obj [get_property name [get_filesets $obj]]
        set fs_active {}
        if { $fs_type == "DesignSrcs" } {
          set fs_active [get_property name [current_fileset]]
        } elseif { $fs_type == "SimulationSrcs" } {
          set fs_active [get_property name [get_filesets $a_sim_vars(fs_obj)]]
        } else {
          send_msg_id exportsim-Tcl-015 ERROR "Invalid simulation fileset '$fs_of_obj' of type '$fs_type' specified with the -of_objects switch. Please specify a 'current' simulation or design source fileset.\n"
          return 1
        }
        
        # must work on the current fileset
        if { $fs_of_obj != $fs_active } {
          [catch {send_msg_id exportsim-Tcl-015 ERROR \
            "The specified fileset '$fs_of_obj' is not 'current' (current fileset is '$fs_active'). Please set '$fs_of_obj' as current fileset using the 'current_fileset' Tcl command and retry this command.\n"} err]
          return 1
        }

        # -of_objects specifed, set default active source set
        if { $fs_type == "DesignSrcs" } {
          set a_sim_vars(fs_obj) [current_fileset]
          set a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj)
          xps_verify_ip_status
          update_compile_order -quiet -fileset $a_sim_vars(sp_tcl_obj)
          set a_sim_vars(s_top) [get_property TOP $a_sim_vars(fs_obj)]
        } elseif { $fs_type == "SimulationSrcs" } {
          set a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj)
          xps_verify_ip_status
          update_compile_order -quiet -fileset $a_sim_vars(sp_tcl_obj)
          set a_sim_vars(s_top) [get_property TOP $a_sim_vars(fs_obj)]
        }
      } else {
        # no -of_objects specifed, set default active simset
        set a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj)
        xps_verify_ip_status
        update_compile_order -quiet -fileset $a_sim_vars(sp_tcl_obj)
        set a_sim_vars(s_top) [get_property TOP $a_sim_vars(fs_obj)]
      }
    }
  }
  return 0
}

proc xps_gen_mem_files { run_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable s_embedded_files_filter
  variable l_target_simulator
  set embedded_files [get_files -all -quiet -filter $s_embedded_files_filter]
  if { [llength $embedded_files] > 0 } {
    #send_msg_id exportsim-Tcl-016 INFO "Design contains embedded sources, generating MEM files for simulation...\n"
    generate_mem_files $run_dir
  }
}

proc xps_copy_glbl { run_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if { [xps_contains_verilog] } {
    set data_dir [rdi::get_data_dir -quiet -datafile verilog/src/glbl.v]
    set glbl_file [file normalize [file join $data_dir "verilog/src/glbl.v"]]
    if { [file exists $glbl_file] } {
      set target_file [file normalize [file join $run_dir "glbl.v"]]
      if { ![file exists $target_file] } {
        if {[catch {file copy -force $glbl_file $run_dir} error_msg] } {
          send_msg_id exportsim-Tcl-041 WARNING "failed to copy file '$glbl_file' to '$run_dir' : $error_msg\n"
        }
      }
    }
  }
}

proc xps_xport_data_files { data_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable s_data_files_filter
  variable s_non_hdl_data_files_filter
  upvar $data_files_arg data_files
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xps_is_ip $tcl_obj] } {
    set ip_filter "FILE_TYPE == \"IP\""
    set ip_name [file tail $tcl_obj]
    set data_files [concat $data_files [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $s_data_files_filter]]
    foreach file [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $s_non_hdl_data_files_filter] {
      if { [lsearch -exact [list_property $file] {IS_USER_DISABLED}] != -1 } {
        if { [get_property {IS_USER_DISABLED} $file] } {
          continue;
        }
      }
      lappend data_files $file
    }
  } elseif { [xps_is_fileset $tcl_obj] } {
    xps_export_fs_data_files $s_data_files_filter data_files
    xps_export_fs_non_hdl_data_files data_files
  } else {
    send_msg_id exportsim-Tcl-017 INFO "Unsupported object source: $tcl_obj\n"
    return 1
  }
}

proc xps_export_fs_non_hdl_data_files { data_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable s_non_hdl_data_files_filter
  upvar $data_files_arg data_files
  foreach file [get_files -all -quiet -of_objects [get_filesets $a_sim_vars(fs_obj)] -filter $s_non_hdl_data_files_filter] {
    if { [lsearch -exact [list_property $file] {IS_USER_DISABLED}] != -1 } {
      if { [get_property {IS_USER_DISABLED} $file] } {
        continue;
      }
    }
    lappend data_files $file
  }
}

proc xps_process_cmd_str { simulator dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set b_lang_updated 0
  set curr_lang [string tolower [get_property simulator_language [current_project]]]
  if { $a_sim_vars(b_ip_netlist) } {
    if { $curr_lang != $a_sim_vars(s_ip_netlist) } {
      set_property simulator_language $a_sim_vars(s_ip_netlist) [current_project]
      set b_lang_updated 1
    }
  }
  set a_sim_vars(l_design_files) [xps_uniquify_cmd_str [xps_get_files $simulator $dir]]
  if { $b_lang_updated } {
    set_property simulator_language $curr_lang [current_project]
  }
}

proc xps_get_files { simulator launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compile_order_files
  set files          [list]
  set l_compile_order_files [list]
  set target_obj        $a_sim_vars(sp_tcl_obj)
  set linked_src_set {}
  if { ([xps_is_fileset $a_sim_vars(sp_tcl_obj)]) && ({SimulationSrcs} == [get_property fileset_type $a_sim_vars(fs_obj)]) } {
    set linked_src_set [get_property "SOURCE_SET" $a_sim_vars(fs_obj)]
  }
  set target_lang    [get_property "TARGET_LANGUAGE" [current_project]]
  set src_mgmt_mode  [get_property "SOURCE_MGMT_MODE" [current_project]]
  set incl_file_paths [list]
  set incl_files      [list]

  #send_msg_id exportsim-Tcl-018 INFO "Finding global include files..."
  set prefix_ref_dir "false"
  switch $simulator {
    "ies" -
    "vcs" {
      set prefix_ref_dir "true"
    }
  }
  xps_get_global_include_files $launch_dir incl_file_paths incl_files $prefix_ref_dir

  set global_incl_files $incl_files
  set a_sim_vars(global_files_str) [xps_get_global_include_file_cmdstr $simulator $launch_dir incl_files]

  #send_msg_id exportsim-Tcl-019 INFO "Finding include directories and verilog header directory paths..."
  set l_incl_dirs_opts [list]
  set l_verilog_incl_dirs [list]
  set uniq_dirs [list]
  foreach dir [concat [xps_get_verilog_incl_dirs $simulator $launch_dir $prefix_ref_dir] [xps_get_verilog_incl_file_dirs $simulator $launch_dir $prefix_ref_dir]] {
    lappend l_verilog_incl_dirs $dir
    if { {vcs} == $simulator } {
      set dir [string trim $dir "\""]
      regsub -all { } $dir {\\\\ } dir
    }
    if { [lsearch -exact $uniq_dirs $dir] == -1 } {
      lappend uniq_dirs $dir
      if { ({questa} == $simulator) || ({modelsim} == $simulator) } {
        lappend l_incl_dirs_opts "\"+incdir+$dir\""
      } else {
        lappend l_incl_dirs_opts "+incdir+\"$dir\""
      }
    }
  }
  if { [xps_is_fileset $target_obj] } {
    set used_in_val "simulation"
    switch [get_property "FILESET_TYPE" [get_filesets $target_obj]] {
      "DesignSrcs"     { set used_in_val "synthesis" }
      "SimulationSrcs" { set used_in_val "simulation"}
      "BlockSrcs"      { set used_in_val "synthesis" }
    }
    set xpm_libraries [get_property -quiet xpm_libraries [current_project]]
    foreach library $xpm_libraries {
      foreach file [rdi::get_xpm_files -library_name $library] {
        set file_type "SystemVerilog"
        set compiler [xps_get_compiler $simulator $file_type]
        set l_other_compiler_opts [list]
        xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_verilog_incl_dirs l_other_compiler_opts
        set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type $compiler l_other_compiler_opts l_incl_dirs_opts 1]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
        }
      }
    }
    set b_add_sim_files 1
    if { {} != $linked_src_set } {
      if { [get_param project.addBlockFilesetFilesForUnifiedSim] } {
        xps_add_block_fs_files $simulator $launch_dir l_incl_dirs_opts l_verilog_incl_dirs files l_compile_order_files
      }
    }

    if { {All} == $src_mgmt_mode } {
      #send_msg_id exportsim-Tcl-020 INFO "Fetching design files from '$target_obj'..."
      foreach file [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $target_obj]] {
        if { [xps_is_global_include_file $file] } { continue }
        set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
        set compiler [xps_get_compiler $simulator $file_type]
        set l_other_compiler_opts [list]
        xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_verilog_incl_dirs l_other_compiler_opts
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
        set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type $compiler l_other_compiler_opts l_incl_dirs_opts]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
        }
      }
      set b_add_sim_files 0
    } else {
      if { {} != $linked_src_set } {
        set srcset_obj [get_filesets $linked_src_set]
        if { {} != $srcset_obj } {
          set used_in_val "simulation"
          #send_msg_id exportsim-Tcl-021 INFO "Fetching design files from '$srcset_obj'...(this may take a while)..."
          foreach file [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $srcset_obj]] {
            set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
            set compiler [xps_get_compiler $simulator $file_type]
            set l_other_compiler_opts [list]
            xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_verilog_incl_dirs l_other_compiler_opts
            if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
            set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type $compiler l_other_compiler_opts l_incl_dirs_opts]
            if { {} != $cmd_str } {
              lappend files $cmd_str
              lappend l_compile_order_files $file
            }
          }
        }
      }
    }

    if { $b_add_sim_files } {
      #send_msg_id exportsim-Tcl-022 INFO "Fetching design files from '$a_sim_vars(fs_obj)'..."
      foreach file [get_files -quiet -all -of_objects $a_sim_vars(fs_obj)] {
        set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
        set compiler [xps_get_compiler $simulator $file_type]
        set l_other_compiler_opts [list]
        xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_verilog_incl_dirs l_other_compiler_opts
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
        if { [get_property "IS_AUTO_DISABLED" [lindex [get_files -quiet -all [list "$file"]] 0]]} { continue }
        set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type $compiler l_other_compiler_opts l_incl_dirs_opts]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
        }
      }
    }
  } elseif { [xps_is_ip $target_obj] } {
    #send_msg_id exportsim-Tcl-023 INFO "Fetching design files from IP '$target_obj'..."
    set ip_filename [file tail $target_obj]
    foreach file [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_filename]] {
      set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
      set compiler [xps_get_compiler $simulator $file_type]
      set l_other_compiler_opts [list]
      xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_verilog_incl_dirs l_other_compiler_opts
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
      set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type $compiler l_other_compiler_opts l_incl_dirs_opts]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        lappend l_compile_order_files $file
      }
    }
  }
  return $files
}

proc xps_get_ip_file_from_repo { ip_file src_file library launch_dir b_static_ip_file_arg  } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_ip_static_libs
  upvar $b_static_ip_file_arg b_static_ip_file
  if { ![get_param project.enableCentralSimRepo] } { return $src_file }
  #if { $a_sim_vars(b_xport_src_files) }            { return $src_file }
  if { {} == $ip_file }                            { return $src_file }

  if { ({} != $a_sim_vars(dynamic_repo_dir)) && ([file exist $a_sim_vars(dynamic_repo_dir)]) } {
    set b_is_static 0
    set b_is_dynamic 0
    set src_file [xps_get_source_from_repo $ip_file $src_file $launch_dir b_is_static b_is_dynamic]
    set b_static_ip_file $b_is_static
    if { (!$b_is_static) && (!$b_is_dynamic) } {
      send_msg_id exportsim-Tcl-056 "CRITICAL WARNING" "IP file is neither static or dynamic:'$src_file'\n"
    }
    # phase-2
    if { $b_is_static } {
      set b_static_ip_file 1
      lappend l_ip_static_libs [string tolower $library]
    }
  }

  return $src_file
}

proc xps_get_source_from_repo { ip_file orig_src_file launch_dir b_is_static_arg b_is_dynamic_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  upvar $b_is_static_arg b_is_static
  upvar $b_is_dynamic_arg b_is_dynamic

  #puts org_file=$orig_src_file
  set src_file $orig_src_file

  set b_wrap_in_quotes 0
  if { [regexp {\"} $src_file] } {
    set b_wrap_in_quotes 1
    regsub -all {\"} $src_file {} src_file
  }

  set b_add_ref 0 
  if {[regexp -nocase {^\$ref_dir} $src_file]} {
    set b_add_ref 1
    set src_file [string range $src_file 9 end]
    set src_file "$src_file"
  }
  #puts src_file=$src_file
  set filename [file tail $src_file]
  #puts ip_file=$ip_file
  set ip_name [file root [file tail $ip_file]] 

  set full_src_file_path [xps_find_file_from_compile_order $ip_name $src_file]
  #puts ful_file=$full_src_file_path
  set full_src_file_obj [lindex [get_files -all [list "$full_src_file_path"]] 0]  
  #puts ip_name=$ip_name

  set dst_cip_file $full_src_file_path
  set used_in_values [get_property "USED_IN" $full_src_file_obj]
  # is dynamic?
  if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
    if { [xps_is_core_container $ip_file $ip_name] } {
      set dst_cip_file [xps_get_dynamic_sim_file_core_container $full_src_file_path]
    } else {
      set dst_cip_file [xps_get_dynamic_sim_file_core_classic $full_src_file_path]
    }
  }

  set b_is_dynamic 1
  set bd_file {}
  set b_is_bd_ip [xps_is_bd_file $full_src_file_path bd_file]
  set bd_filename [file tail $bd_file]

  # is static ip file? set flag and return
  #puts ip_name=$ip_name
  if { $b_is_bd_ip } {
    set ip_static_file [lindex [get_files -quiet -all -of_objects [get_files -all -quiet $bd_filename] [list "$full_src_file_path"] -filter {USED_IN=~"*ipstatic*"}] 0]
  } else {
    set ip_static_file [lindex [get_files -quiet -all -of_objects [get_ips -all -quiet $ip_name] [list "$full_src_file_path"] -filter {USED_IN=~"*ipstatic*"}] 0]
  }
  if { {} != $ip_static_file } {
    #puts ip_static_file=$ip_static_file
    set b_is_static 1
    set b_is_dynamic 0
    set dst_cip_file $ip_static_file 

    if { $a_sim_vars(b_use_static_lib) } {
      # use pre-compiled lib
    } else {
      if { $b_is_bd_ip } {
        set dst_cip_file [xps_fetch_ipi_static_file $ip_static_file] 
      } else {
        # get the parent composite file for this static file
        set parent_comp_file [get_property parent_composite_file -quiet [lindex [get_files -all [list "$ip_static_file"]] 0]]

        # calculate destination path
        set dst_cip_file [xps_find_ipstatic_file_path $ip_static_file $parent_comp_file]

        # skip if file exists
        if { ({} == $dst_cip_file) || (![file exists $dst_cip_file]) } {
          # if parent composite file is empty, extract to default ipstatic dir (the extracted path is expected to be
          # correct in this case starting from the library name (e.g fifo_generator_v13_0_0/hdl/fifo_generator_v13_0_rfs.vhd))
          if { {} == $parent_comp_file } {
            set dst_cip_file [extract_files -no_ip_dir -quiet -files [list "$ip_static_file"] -base_dir $a_sim_vars(ipstatic_dir)]
            #puts extracted_file_no_pc=$dst_cip_file
          } else {
            # parent composite is not empty, so get the ip output dir of the parent composite and subtract it from source file
            set parent_ip_name [file root [file tail $parent_comp_file]]
            set ip_output_dir [get_property ip_output_dir [get_ips -all $parent_ip_name]]
            #puts src_ip_file=$ip_static_file
  
            # get the source ip file dir
            set src_ip_file_dir [file dirname $ip_static_file]
    
            # strip the ip_output_dir path from source ip file and prepend static dir
            set lib_dir [xps_get_sub_file_path $src_ip_file_dir $ip_output_dir]
            set target_extract_dir [file normalize [file join $a_sim_vars(ipstatic_dir) $lib_dir]]
            #puts target_extract_dir=$target_extract_dir
    
            set dst_cip_file [extract_files -no_path -quiet -files [list "$ip_static_file"] -base_dir $target_extract_dir]
            #puts extracted_file_with_pc=$dst_cip_file
          }
        }
      }
    }
  }

  if { [file exist $dst_cip_file] } {
    if { $a_sim_vars(b_absolute_path) } {
      set dst_cip_file "[xps_resolve_file_path $dst_cip_file $launch_dir]"
    } else {
      if { $b_add_ref } {
        set dst_cip_file "\$ref_dir/[xps_get_relative_file_path $dst_cip_file $launch_dir]"
      } else {
        set dst_cip_file "[xps_get_relative_file_path $dst_cip_file $launch_dir]"
      }
    }
    if { $b_wrap_in_quotes } {
      set dst_cip_file "\"$dst_cip_file\""
    }
    set orig_src_file $dst_cip_file
  }
  return $orig_src_file
}

proc xps_find_top_level_ip_file { src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set comp_file $src_file
  #puts "-----\n  +$src_file"
  set MAX_PARENT_COMP_LEVELS 10
  set count 0
  while (1) {
    incr count
    if { $count > $MAX_PARENT_COMP_LEVELS } { break }
    set file_obj [lindex [get_files -all -quiet [list "$comp_file"]] 0]
    if { {} == $file_obj } {
      # try from filename (this may be from .ext dir when -export_src_files is specified)
      set file_name [file tail $comp_file]
      set file_obj [lindex [get_files -all "$file_name"] 0]
      set comp_file $file_obj
    }
    set props [list_property $file_obj]
    if { [lsearch $props "PARENT_COMPOSITE_FILE"] == -1 } {
      break
    }
    set comp_file [get_property parent_composite_file -quiet $file_obj]
    #puts "  +$comp_file"
  }
  #puts "  +[file root [file tail $comp_file]]"
  #puts "-----\n"
  return $comp_file
}

proc xps_is_bd_file { src_file bd_file_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $bd_file_arg bd_file
  set b_is_bd 0
  set comp_file $src_file
  set MAX_PARENT_COMP_LEVELS 10
  set count 0
  while (1) {
    incr count
    if { $count > $MAX_PARENT_COMP_LEVELS } { break }
    set file_obj [lindex [get_files -all -quiet [list "$comp_file"]] 0]
    set props [list_property $file_obj]
    if { [lsearch $props "PARENT_COMPOSITE_FILE"] == -1 } {
      break
    }
    set comp_file [get_property parent_composite_file -quiet $file_obj]
  }

  # got top-most file whose parent-comp is empty ... is this BD?
  if { {.bd} == [file extension $comp_file] } {
    set b_is_bd 1
    set bd_file $comp_file
  }
  return $b_is_bd
}

proc xps_fetch_ip_static_file { file vh_file_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  if { $a_sim_vars(b_use_static_lib) } {
    return $file
  }

  # /tmp/tp/tp.srcs/sources_1/ip/my_ip/bd_0/ip/ip_2/axi_infrastructure_v1_1_0/hdl/verilog/axi_infrastructure_v1_1_0_header.vh
  set src_ip_file $file
  set src_ip_file [string map {\\ /} $src_ip_file]
  #puts src_ip_file=$src_ip_file

  # get parent composite file path dir
  set comp_file [get_property parent_composite_file -quiet $vh_file_obj]
  set comp_file_dir [file dirname $comp_file]
  set comp_file_dir [string map {\\ /} $comp_file_dir]
  # /tmp/tp/tp.srcs/sources_1/ip/my_ip/bd_0/ip/ip_2
  #puts comp_file_dir=$comp_file_dir

  # strip parent dir from file path dir
  set lib_file_path {}
  # axi_infrastructure_v1_1_0/hdl/verilog/axi_infrastructure_v1_1_0_header.vh

  set src_file_dirs  [file split [file normalize $src_ip_file]]
  set comp_file_dirs [file split [file normalize $comp_file_dir]]
  set src_file_len [llength $src_file_dirs]
  set comp_dir_len [llength $comp_file_dir]

  set index 1
  #puts src_file_dirs=$src_file_dirs
  #puts com_file_dirs=$comp_file_dirs
  while { [lindex $src_file_dirs $index] == [lindex $comp_file_dirs $index] } {
    incr index
    if { ($index == $src_file_len) || ($index == $comp_dir_len) } {
      break;
    }
  }
  set lib_file_path [join [lrange $src_file_dirs $index end] "/"]
  #puts lib_file_path=$lib_file_path

  set dst_cip_file [file join $a_sim_vars(ipstatic_dir) $lib_file_path]
  # /tmp/tp/tp.ip_user_files/ipstatic/axi_infrastructure_v1_1_0/hdl/verilog/axi_infrastructure_v1_1_0_header.vh
  #puts dst_cip_file=$dst_cip_file
  return $dst_cip_file
}

proc xps_fetch_ipi_static_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set src_ip_file $file

  if { $a_sim_vars(b_use_static_lib) } {
    return $src_ip_file
  }

  set comps [lrange [split $src_ip_file "/"] 0 end]
  set to_match "xilinx.com"
  set index 0
  set b_found [xps_find_comp comps index $to_match]
  if { !$b_found } {
    set to_match "user_company"
    set b_found [xps_find_comp comps index $to_match]
  }
  if { !$b_found } {
    return $src_ip_file
  }

  set file_path_str [join [lrange $comps 0 $index] "/"]
  set ip_lib_dir "$file_path_str"

  #puts ip_lib_dir=$ip_lib_dir
  set ip_lib_dir_name [file tail $ip_lib_dir]
  set target_ip_lib_dir [file join $a_sim_vars(ipstatic_dir) $ip_lib_dir_name]
  #puts target_ip_lib_dir=$target_ip_lib_dir

  # get the sub-dir path after "xilinx.com/xbip_utils_v3_0"
  set ip_hdl_dir [join [lrange $comps 0 $index] "/"]
  set ip_hdl_dir "$ip_hdl_dir"
  # /demo/ipshared/xilinx.com/xbip_utils_v3_0/hdl
  #puts ip_hdl_dir=$ip_hdl_dir
  incr index
  set ip_hdl_sub_dir [join [lrange $comps $index end] "/"]
  # /hdl/xbip_utils_v3_0_vh_rfs.vhd
  #puts ip_hdl_sub_dir=$ip_hdl_sub_dir

  set dst_cip_file [file join $target_ip_lib_dir $ip_hdl_sub_dir]
  #puts dst_cip_file=$dst_cip_file

  # repo static file does not exist? maybe generate_target or export_ip_user_files was not executed, fall-back to project src file
  if { ![file exists $dst_cip_file] } {
    return $src_ip_file
  }

  return $dst_cip_file
}

proc xps_get_dynamic_sim_file_core_container { src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set filename  [file tail $src_file]
  set file_dir  [file dirname $src_file]
  set file_obj  [lindex [get_files -all [list "$src_file"]] 0]
  set xcix_file [get_property core_container $file_obj]
  set core_name [file root [file tail $xcix_file]]

  set parent_comp_file      [get_property parent_composite_file -quiet $file_obj]
  set parent_comp_file_type [get_property file_type [lindex [get_files -all [list "$parent_comp_file"]] 0]]

  set ip_dir {}
  if { {Block Designs} == $parent_comp_file_type } {
    set ip_dir [file join [file dirname $xcix_file] $core_name]
  } else {
    set top_ip_file_name {}
    set ip_dir [xps_get_ip_output_dir_from_parent_composite $src_file top_ip_file_name]
  }
  set hdl_dir_file [xps_get_sub_file_path $file_dir $ip_dir]
  set repo_src_file [file join $a_sim_vars(dynamic_repo_dir) "ip" $core_name $hdl_dir_file $filename]

  if { [file exists $repo_src_file] } { 
    return $repo_src_file
  }

  #send_msg_id exportsim-Tcl-024 WARNING "Corresponding IP user file does not exist:'$repo_src_file'!, using default:'$src_file'"
  return $src_file
}

proc xps_get_dynamic_sim_file_core_classic { src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set filename  [file tail $src_file]
  set file_dir  [file dirname $src_file]
  set file_obj  [lindex [get_files -all [list "$src_file"]] 0]

  set top_ip_file_name {}
  set ip_dir [xps_get_ip_output_dir_from_parent_composite $src_file top_ip_file_name]
  set hdl_dir_file [xps_get_sub_file_path $file_dir $ip_dir]

  set top_ip_name [file root [file tail $top_ip_file_name]]
  set extn [file extension $top_ip_file_name]
  set repo_src_file {}
  set sub_dir "ip"
  if { {.bd} == $extn } {
    set sub_dir "bd"
  }
  set repo_src_file [file join $a_sim_vars(dynamic_repo_dir) $sub_dir $top_ip_name $hdl_dir_file $filename]
  if { [file exists $repo_src_file] } {
    return $repo_src_file
  }
  return $src_file
}

proc xps_get_ip_output_dir_from_parent_composite { src_file top_ip_file_name_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $top_ip_file_name_arg top_ip_file_name
  set comp_file $src_file
  set MAX_PARENT_COMP_LEVELS 10
  set count 0
  while (1) {
    incr count
    if { $count > $MAX_PARENT_COMP_LEVELS } { break }
    set file_obj [lindex [get_files -all -quiet [list "$comp_file"]] 0]
    set props [list_property $file_obj]
    if { [lsearch $props "PARENT_COMPOSITE_FILE"] == -1 } {
      break
    }
    set comp_file [get_property parent_composite_file -quiet $file_obj]
    #puts "+comp_file=$comp_file"
  }
  set top_ip_name [file root [file tail $comp_file]]
  set top_ip_file_name $comp_file

  set root_comp_file_type [get_property file_type [lindex [get_files -all [list "$comp_file"]] 0]]
  if { {Block Designs} == $root_comp_file_type } {
    set ip_output_dir [file dirname $comp_file]
  } else {
    set ip_output_dir [get_property ip_output_dir [get_ips -all $top_ip_name]]
  }
  return $ip_output_dir
}

proc xps_fetch_header_from_dynamic { vh_file b_is_bd } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  #puts vh_file=$vh_file
  set ip_file [xps_get_top_ip_filename $vh_file]
  if { {} == $ip_file } {
    return $vh_file
  }
  set ip_name [file root [file tail $ip_file]]
  #puts ip_name=$ip_name

  # if not core-container (classic), return original source file from project
  if { ![xps_is_core_container $ip_file $ip_name] } {
    return $vh_file
  }

  set vh_filename   [file tail $vh_file]
  set vh_file_dir   [file dirname $vh_file]
  set output_dir    [get_property IP_OUTPUT_DIR [lindex [get_ips -all $ip_name] 0]]
  set sub_file_path [xps_get_sub_file_path $vh_file_dir $output_dir]

  # construct full repo dynamic file path
  set sub_dir "ip"
  if { $b_is_bd } {
    set sub_dir "bd"
  }
  set vh_file [file join $a_sim_vars(dynamic_repo_dir) $sub_dir $ip_name $sub_file_path $vh_filename]
  #puts vh_file=$vh_file

  return $vh_file
}

proc xps_get_sub_file_path { src_file_path dir_path_to_remove } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set src_path_comps [file split [file normalize $src_file_path]]
  set dir_path_comps [file split [file normalize $dir_path_to_remove]]

  set src_path_len [llength $src_path_comps]
  set dir_path_len [llength $dir_path_comps]

  set index 1
  while { [lindex $src_path_comps $index] == [lindex $dir_path_comps $index] } {
    incr index
    if { ($index == $src_path_len) || ($index == $dir_path_len) } {
      break;
    }
  }
  set sub_file_path [join [lrange $src_path_comps $index end] "/"]
  return $sub_file_path
}

proc xps_is_core_container { ip_file ip_name } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set b_is_container 1
  if { [get_property sim.use_central_dir_for_ips [current_project]] } {
    return $b_is_container
  }

  set file_extn [file extension $ip_file]
  #puts $ip_name=$file_extn

  # is this ip core-container? if not return 0 (classic)
  set value [string trim [get_property core_container [get_files -all -quiet ${ip_name}${file_extn}]]]
  if { {} == $value } {
    set b_is_container 0
  }
  return $b_is_container
}

proc xps_find_ipstatic_file_path { src_ip_file parent_comp_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set dest_file {}
  set filename [file tail $src_ip_file]
  set file_obj [lindex [get_files -quiet -all [list "$src_ip_file"]] 0]
  if { {} == $file_obj } {
    set file_obj [lindex [get_files -quiet -all $filename] 0]
  }
  if { {} == $file_obj } {
    return $dest_file
  } 

  if { {} == $parent_comp_file } {
    set library_name [get_property library $file_obj]
    set comps [lrange [split $src_ip_file "/"] 1 end]
    set index 0
    set b_found false
    set to_match $library_name
    set b_found [xps_find_comp comps index $to_match]
    if { $b_found } {
      set file_path_str [join [lrange $comps $index end] "/"]
      #puts file_path_str=$file_path_str
      set dest_file [file normalize [file join $a_sim_vars(ipstatic_dir) $file_path_str]]
    }
  } else {
    set parent_ip_name [file root [file tail $parent_comp_file]]
    set ip_output_dir [get_property ip_output_dir [get_ips -all $parent_ip_name]]
    set src_ip_file_dir [file dirname $src_ip_file]
    set lib_dir [xif_get_sub_file_path $src_ip_file_dir $ip_output_dir]
    set target_extract_dir [file normalize [file join $a_sim_vars(ipstatic_dir) $lib_dir]]
    set dest_file [file join $target_extract_dir $filename]
  }
  return $dest_file
}

proc xps_find_file_from_compile_order { ip_name src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  #puts src_file=$src_file
  set file [string map {\\ /} $src_file]

  set sub_dirs [list]
  set comps [lrange [split $file "/"] 1 end]
  foreach comp $comps {
    if { {.} == $comp } continue;
    if { {..} == $comp } continue;
    lappend sub_dirs $comp
  }
  set file_path_str [join $sub_dirs "/"]

  set str_to_replace "/${ip_name}/"
  set str_replace_with "/${ip_name}/"
  regsub -all $str_to_replace $file_path_str $str_replace_with file_path_str
  #puts file_path_str_mod=$file_path_str 

  foreach file [xps_get_compile_order_files] {
    set file [string map {\\ /} $file]
    #puts +co_file=$file
    if { [string match *$file_path_str $file] } {
      set src_file $file
      break
    }
  }
  #puts out_file=$src_file
  return $src_file
}

proc xps_is_ip { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable l_valid_ip_extns 
  if { [lsearch -exact $l_valid_ip_extns [file extension $tcl_obj]] >= 0 } {
    return 1
  } else {
    if {[regexp -nocase {^ip} [get_property -quiet [rdi::get_attr_specs CLASS -object $tcl_obj] $tcl_obj]] } {
      return 1
    }
  }
  return 0
}

proc xps_is_fileset { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  set spec_list [rdi::get_attr_specs -quiet -object $tcl_obj -regexp .*FILESET_TYPE.*]
  if { [llength $spec_list] > 0 } {
    if {[regexp -nocase {^fileset_type} $spec_list]} {
      return 1
    }
  }
  return 0
}

proc xps_uniquify_cmd_str { cmd_strs } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set cmd_str_set   [list]
  set uniq_cmd_strs [list]
  foreach str $cmd_strs {
    if { [lsearch -exact $cmd_str_set $str] == -1 } {
      lappend cmd_str_set $str
      lappend uniq_cmd_strs $str
    }
  }
  return $uniq_cmd_strs
}

proc xps_add_block_fs_files { simulator launch_dir l_incl_dirs_opts_arg l_verilog_incl_dirs_arg files_arg compile_order_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $l_incl_dirs_opts_arg l_incl_dirs_opts
  upvar $l_verilog_incl_dirs_arg l_verilog_incl_dirs 
  upvar $files_arg files
  upvar $compile_order_files_arg compile_order_files

  #send_msg_id exportsim-Tcl-024 INFO "Finding block fileset files..."
  set vhdl_filter "FILE_TYPE == \"VHDL\" || FILE_TYPE == \"VHDL 2008\""
  foreach file [xps_get_files_from_block_filesets $vhdl_filter] {
    set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
    set compiler [xps_get_compiler $simulator $file_type]
    set l_other_compiler_opts [list]
    xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_verilog_incl_dirs l_other_compiler_opts
    set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type $compiler {} l_other_compiler_opts l_incl_dirs_opts]
    if { {} != $cmd_str } {
      lappend files $cmd_str
      lappend compile_order_files $file
    }
  }
  set verilog_filter "FILE_TYPE == \"Verilog\" || FILE_TYPE == \"SystemVerilog\""
  foreach file [xps_get_files_from_block_filesets $verilog_filter] {
    set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
    set compiler [xps_get_compiler $simulator $file_type]
    set l_other_compiler_opts [list]
    xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_verilog_incl_dirs l_other_compiler_opts
    set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type $compiler l_other_compiler_opts l_incl_dirs_opts]
    if { {} != $cmd_str } {
      lappend files $cmd_str
      lappend compile_order_files $file
    }
  }
}

proc xps_get_files_from_block_filesets { filter_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set file_list [list]
  set filter "FILESET_TYPE == \"BlockSrcs\""
  set used_in_val "simulation"
  set fs_objs [get_filesets -filter $filter]
  if { [llength $fs_objs] > 0 } {
    foreach fs_obj $fs_objs {
      set fs_name [get_property "NAME" $fs_obj]
      set files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $fs_obj] -filter $filter_type]
      if { [llength $files] > 0 } {
        foreach file $files {
          lappend file_list $file
        }
      }
    }
  }
  return $file_list
}

proc xps_get_cmdstr { simulator launch_dir file file_type compiler l_other_compiler_opts_arg  l_incl_dirs_opts_arg {b_skip_file_obj_access 0} } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  upvar $l_other_compiler_opts_arg l_other_compiler_opts
  upvar $l_incl_dirs_opts_arg l_incl_dirs_opts
  set b_absolute_path $a_sim_vars(b_absolute_path)
  set cmd_str {}
  set associated_library [get_property "DEFAULT_LIB" [current_project]]
  set srcs_dir [file normalize [file join $launch_dir "srcs"]]
  if { $b_skip_file_obj_access } {
    #
  } else {
    set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
    if { {} != $file_obj } {
      if { [lsearch -exact [list_property $file_obj] {LIBRARY}] != -1 } {
        set associated_library [get_property "LIBRARY" $file_obj]
      }
      if { ($a_sim_vars(b_extract_ip_sim_files) || $a_sim_vars(b_xport_src_files)) } {
        set xcix_ip_path [get_property core_container $file_obj]
        if { {} != $xcix_ip_path } {
          set ip_name [file root [file tail $xcix_ip_path]]
          set ip_ext_dir [get_property ip_extract_dir [get_ips -all -quiet $ip_name]]
          set ip_file "[xps_get_relative_file_path $file $ip_ext_dir]"
          # remove leading "../"
          set ip_file [join [lrange [split $ip_file "/"] 1 end] "/"]
          set file [file join $ip_ext_dir $ip_file]
        } else {
          # set file [extract_files -files [list "$file"] -base_dir $launch_dir/ip_files]
        }
      }
    }
  }

  set src_file $file

  set ip_file {}
  if { $b_skip_file_obj_access } {
    #
  } else {
    set ip_file [xps_get_top_ip_filename $src_file]
    set b_static_ip_file 0
    if { $a_sim_vars(b_xport_src_files) } {
      # no-op
    } else {
      set file [xps_get_ip_file_from_repo $ip_file $src_file $associated_library $launch_dir b_static_ip_file]
    }
    #puts file=$file
  }

  set arg_list [list]
  if { [string length $compiler] > 0 } {
    lappend arg_list $compiler
    switch $simulator {
      "xsim" {}
      default {
        set arg_list [linsert $arg_list end "-work"]
      }
    }
    set arg_list [linsert $arg_list end "$associated_library"]
    if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } {
      # do not add global files for 2008
    } else {
      if { {} != $a_sim_vars(global_files_str) } {
        set arg_list [linsert $arg_list end [xps_resolve_global_file_paths $simulator $launch_dir]]
      }
    }
  }

  set arg_list [concat $arg_list $l_other_compiler_opts]
  if { {vlog} == $compiler } {
    set arg_list [concat $arg_list $l_incl_dirs_opts]
  }
  set file_str [join $arg_list " "]
  set type [xps_get_file_type_category $file_type]


  set cmd_str "$type|$file_type|$associated_library|$src_file|$file_str|$ip_file|\"$file\"|$b_static_ip_file"
  return $cmd_str
}

proc xps_resolve_global_file_paths { simulator launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set file_paths [string trim $a_sim_vars(global_files_str)]
  if { {} == $file_paths } { return $file_paths }

  set resolved_file_paths [list]
  foreach g_file [split $file_paths {|}] {
    set file [string trim $g_file {\"}]
    set src_file [file tail $file]
    if { $a_sim_vars(b_absolute_path) } {
      switch -regexp -- $simulator {
        "ies" -
        "vcs" {
          if { $a_sim_vars(b_xport_src_files) } {
            set file "\$ref_dir/incl/$src_file"
          } else {
            set file [file normalize $file]
          }
        }
        default {
          if { $a_sim_vars(b_xport_src_files) } {
            set file [file join $launch_dir "srcs/incl/$src_file"]
          } else {
            set file "[xps_resolve_file_path $file $launch_dir]"
          }
        }
      }
    } else {
      switch -regexp -- $simulator {
        "ies" -
        "vcs" {
          if { $a_sim_vars(b_xport_src_files) } {
            set file "\$ref_dir/incl/$src_file"
          } else {
            set file "\$ref_dir/[xps_get_relative_file_path $file $launch_dir]"
          }
        }
        default {
          if { $a_sim_vars(b_xport_src_files) } {
            set file "srcs/incl/$src_file"
          } else {
            set file "[xps_get_relative_file_path $file $launch_dir]"
          }
        }
      }
    }
    lappend resolved_file_paths "\"$file\""
  }
  return [join $resolved_file_paths " "]
} 

proc xps_get_top_ip_filename { src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top_ip_file {}

  # find file by full path
  set file_obj [lindex [get_files -all -quiet $src_file] 0]

  # not found, try from source filename
  if { {} == $file_obj } {
    set file_obj [lindex [get_files -all -quiet [file tail $src_file]] 0]
  }
  
  if { {} == $file_obj } {
    return $top_ip_file
  }
  
  set props [list_property $file_obj]
  # get the hierarchical top level ip file name if parent comp file is defined
  if { [lsearch $props "PARENT_COMPOSITE_FILE"] != -1 } {
    set top_ip_file [xps_find_top_level_ip_file $src_file]
  }
  return $top_ip_file
}

proc xps_get_file_type_category { file_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set type {UNKNOWN}
  switch $file_type {
    {VHDL} -
    {VHDL 2008} {
      set type {VHDL}
    }
    {Verilog} -
    {SystemVerilog} -
    {Verilog Header} {
      set type {VERILOG}
    }
  }
  return $type
}

proc xps_get_design_libs {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set libs [list]
  foreach file $a_sim_vars(l_design_files) {
    set fargs     [split $file {|}]
    set type      [lindex $fargs 0]
    set file_type [lindex $fargs 1]
    set library   [lindex $fargs 2]
    if { {} == $library } {
      continue;
    }
    if { [lsearch -exact $libs $library] == -1 } {
      lappend libs $library
    }
  }
  return $libs
}

proc xps_get_relative_file_path { file_path_to_convert relative_to } {
  # Summary:
  # Argument Usage:
  # file_path_to_convert:
  # Return Value:

  variable a_sim_vars
  # make sure we are dealing with a valid relative_to directory. If regular file or is not a directory, get directory
  if { [file isfile $relative_to] || ![file isdirectory $relative_to] } {
    set relative_to [file dirname $relative_to]
  }
  set cwd [file normalize [pwd]]
  if { [file pathtype $file_path_to_convert] eq "relative" } {
    # is relative_to path same as cwd?, just return this path, no further processing required
    if { [string equal $relative_to $cwd] } {
      return $file_path_to_convert
    }
    # the specified path is "relative" but something else, so make it absolute wrt current working dir
    set file_path_to_convert [file join $cwd $file_path_to_convert]
  }
  # is relative_to "relative"? convert to absolute as well wrt cwd
  if { [file pathtype $relative_to] eq "relative" } {
    set relative_to [file join $cwd $relative_to]
  }
  # normalize
  set file_path_to_convert [file normalize $file_path_to_convert]
  set relative_to          [file normalize $relative_to]
  set file_path $file_path_to_convert
  set file_comps        [file split $file_path]
  set relative_to_comps [file split $relative_to]
  set found_match false
  set index 0
  set fc_comps_len [llength $file_comps]
  set rt_comps_len [llength $relative_to_comps]
  # compare each dir element of file_to_convert and relative_to, set the flag and
  # get the final index till these sub-dirs matched
  while { [lindex $file_comps $index] == [lindex $relative_to_comps $index] } {
    if { !$found_match } { set found_match true }
    incr index
    if { ($index == $fc_comps_len) || ($index == $rt_comps_len) } {
      break;
    }
  }
  # any common dirs found? convert path to relative
  if { $found_match } {
    set parent_dir_path ""
    set rel_index $index
    # keep traversing the relative_to dirs and build "../" levels
    while { [lindex $relative_to_comps $rel_index] != "" } {
      set parent_dir_path "../$parent_dir_path"
      incr rel_index
    }
    #
    # at this point we have parent_dir_path setup with exact number of sub-dirs to go up
    #
    # now build up part of path which is relative to matched part
    set rel_path ""
    set rel_index $index
    while { [lindex $file_comps $rel_index] != "" } {
      set comps [lindex $file_comps $rel_index]
      if { $rel_path == "" } {
        # first dir
        set rel_path $comps
      } else {
        # append remaining dirs
        set rel_path "${rel_path}/$comps"
      }
      incr rel_index
    }
    # prepend parent dirs, this is the complete resolved path now
    set resolved_path "${parent_dir_path}${rel_path}"
    return $resolved_path
  }
  # no common dirs found, just return the normalized path
  return $file_path
}

proc xps_resolve_file_path { file_dir_path_to_convert launch_dir } {
  # Summary: Make file path relative to ref_dir if relative component found
  # Argument Usage:
  # file_dir_path_to_convert: input file to make relative to specfied path
  # Return Value:
  # Relative path wrt the path specified

  variable a_sim_vars
  set ref_dir [file normalize [string map {\\ /} $launch_dir]]
  set ref_comps [lrange [split $ref_dir "/"] 1 end]
  set file_comps [lrange [split [file normalize [string map {\\ /} $file_dir_path_to_convert]] "/"] 1 end]
  set index 1
  while { [lindex $ref_comps $index] == [lindex $file_comps $index] } {
    incr index
  }
  # is file path within reference dir? return relative path
  if { $index == [llength $ref_comps] } {
    return [xps_get_relative_file_path $file_dir_path_to_convert $ref_dir]
  }
  # return absolute
  return $file_dir_path_to_convert
}

proc xps_export_fs_data_files { filter data_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  upvar $data_files_arg data_files
  set ips [get_files -all -quiet -filter "FILE_TYPE == \"IP\""]
  foreach ip $ips {
    set ip_name [file tail $ip]
    foreach file [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $filter] {
      lappend data_files $file
    }
  }
  set filesets [list]
  lappend filesets [get_filesets -filter "FILESET_TYPE == \"BlockSrcs\""]
  lappend filesets [current_fileset -srcset]
  lappend filesets $a_sim_vars(fs_obj)

  foreach fs_obj $filesets {
    foreach file [get_files -all -quiet -of_objects [get_filesets $fs_obj] -filter $filter] {
      lappend data_files $file
    }
  }
}

proc xps_export_data_files { data_files export_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_target_simulator
  if { [llength $data_files] > 0 } {
    set data_files [xps_remove_duplicate_files $data_files]
    foreach file $data_files {
      set extn [file extension $file]
      switch -- $extn {
        {.bd} -
        {.png} -
        {.c} -
        {.zip} -
        {.hwh} -
        {.hwdef} -
        {.xml} {
          if { {} != [xps_get_top_ip_filename $file] } {
            continue
          }
        }
      }

      set filename [file tail $file]
      if { ([string match *_bd* $filename]) && ({.tcl} == $extn) } {
        continue
      }
      if { ([string match *_changelog* $filename]) && ({.txt} == $extn) } {
        continue
      }
   
      # mig data files
      set mig_files [list "xsim_run.sh" "ies_run.sh" "vcs_run.sh" "readme.txt" "xsim_files.prj" "xsim_options.tcl" "sim.do"]
      if { [lsearch $mig_files $filename] != -1 } {continue}

      set target_file [file join $export_dir [file tail $file]]
      if { [get_param project.enableCentralSimRepo] } {
        set mem_init_dir [file normalize [file join $a_sim_vars(dynamic_repo_dir) "mem_init_files"]]
        set data_file [extract_files -force -no_paths -files [list "$file"] -base_dir $mem_init_dir]
        if {[catch {file copy -force $data_file $export_dir} error_msg] } {
          send_msg_id exportsim-Tcl-025 WARNING "Failed to copy file '$data_file' to '$export_dir' : $error_msg\n"
        } else {
          send_msg_id exportsim-Tcl-025 INFO "Exported '$target_file'\n"
        }
      } else {
        set data_file [extract_files -force -no_paths -files [list "$file"] -base_dir $export_dir]
        send_msg_id exportsim-Tcl-025 INFO "Exported '$target_file'\n"
      }
    }
  }
}

proc xps_set_script_filename {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xps_is_ip $tcl_obj] } {
    set a_sim_vars(ip_filename) [file tail $tcl_obj]
    if { ! $a_sim_vars(b_script_specified) } {
      set ip_name [file root $a_sim_vars(ip_filename)]
      set a_sim_vars(s_script_filename) "${ip_name}"
    }
  } elseif { [xps_is_fileset $tcl_obj] } {
    if { ! $a_sim_vars(b_script_specified) } {
      set a_sim_vars(s_script_filename) "$a_sim_vars(s_top)"
      if { {} == $a_sim_vars(s_script_filename) } {
        set extn ".sh"
        set a_sim_vars(s_script_filename) "top$extn"
      }
    }
  }

  if { {} != $a_sim_vars(s_script_filename) } {
    set name $a_sim_vars(s_script_filename)
    set index [string last "." $name ]
    if { $index != -1 } {
      set a_sim_vars(s_script_filename) [string range $name 0 [expr $index - 1]]
    }
  }
}

proc xps_write_sim_script { run_dir data_files filename } {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:

  variable a_sim_vars
  variable l_target_simulator
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  foreach simulator $l_target_simulator {
    set simulator_name [xps_get_simulator_pretty_name $simulator] 
    #puts ""
    send_msg_id exportsim-Tcl-035 INFO \
      "Exporting simulation files for \"[string toupper $simulator]\" ($simulator_name)...\n"
    set dir [file join $run_dir $simulator] 
    xps_create_dir $dir
    if { $a_sim_vars(b_xport_src_files) } {
      xps_create_dir [file join $dir "srcs"]
      xps_create_dir [file join $dir "srcs" "incl"]
      xps_create_dir [file join $dir "srcs" "ip"]
    }
    if { [xps_is_ip $tcl_obj] } {
      set a_sim_vars(s_top) [file tail [file root $tcl_obj]]
      #send_msg_id exportsim-Tcl-026 INFO "Inspecting IP design source files for '$a_sim_vars(s_top)'...\n"
      if {[xps_write_script $simulator $dir $filename]} {
        return 1
      }
    } elseif { [xps_is_fileset $tcl_obj] } {
      set a_sim_vars(s_top) [get_property top [get_filesets $tcl_obj]]
      #send_msg_id exportsim-Tcl-027 INFO "Inspecting design source files for '$a_sim_vars(s_top)' in fileset '$tcl_obj'...\n"
      if {[string length $a_sim_vars(s_top)] == 0} {
        set a_sim_vars(s_top) "unknown"
      }
      if {[xps_write_script $simulator $dir $filename]} {
        return 1
      }
    } else {
      #send_msg_id exportsim-Tcl-028 INFO "Unsupported object source: $tcl_obj\n"
      return 1
    }

    xps_export_data_files $data_files $dir
    xps_gen_mem_files $dir
    xps_copy_glbl $dir

    if { [xps_write_simulator_readme $dir] } {
      return 1
    }

    if { [xps_write_plain_filelist $dir] } {
      return 1
    }
    if { [xps_write_filelist_info $dir] } {
      return 1
    }
  }
  return 0
}

proc xps_write_plain_filelist { dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  variable l_target_simulator
  set fh 0
  set file [file join $dir "filelist.f"]
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-066 ERROR "failed to open file to write ($file)\n"
    return 1
  }
  foreach file $a_sim_vars(l_design_files) {
    set fargs         [split $file {|}]
    set proj_src_file [lindex $fargs 3]
    set ip_file       [lindex $fargs 5]
    set src_file      [lindex $fargs 6]
    set b_static_ip   [lindex $fargs 7]
    if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }
    set pfile [xps_resolve_file $proj_src_file $ip_file $src_file $dir]
    puts $fh $pfile
  }
  if { [xps_contains_verilog] } {
    set file "glbl.v"
    if { $a_sim_vars(b_absolute_path) } {
      set file [file normalize [file join $dir $file]]
    }
    puts $fh "$file"
  }
  close $fh
  return 0
}

proc xps_check_script { dir filename } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set file [file normalize [file join $dir $filename]]
  if { [file exists $file] && (!$a_sim_vars(b_overwrite)) } {
    send_msg_id exportsim-Tcl-032 ERROR "Script file exist:'$file'. Use the -force option to overwrite or select 'Overwrite files' from 'File->Export->Export Simulation' dialog box in GUI."
    return 1
  }
  if { [file exists $file] } {
    if {[catch {file delete -force $file} error_msg] } {
      send_msg_id exportsim-Tcl-033 ERROR "failed to delete file ($file): $error_msg\n"
      return 1
    }
    # cleanup other files
    set files [glob -nocomplain -directory $dir *]
    foreach file_path $files {
      if { {srcs} == [file tail $file_path] } { continue }
      if {[catch {file delete -force $file_path} error_msg] } {
        send_msg_id exportsim-Tcl-010 ERROR "failed to delete file ($file_path): $error_msg\n"
        return 1
      }
    }
  }
  return 0
}

proc xps_write_script { simulator dir filename } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars

  if { [xps_check_script $dir $filename] } {
    return 1
  }
  xps_process_cmd_str $simulator $dir
  if { [xps_invalid_flow_options $simulator] } {
    if { {all} == $a_sim_vars(s_simulator) } {
      return 0
    }
    return 1
  }

  xps_write_simulation_script $simulator $dir
  send_msg_id exportsim-Tcl-029 INFO \
    "Script generated: '$dir/$filename'\n"
  return 0
}
 
proc xps_write_simulation_script { simulator dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  set fh_unix 0

  set file [file join $dir $a_sim_vars(s_script_filename)] 
  set file_unix ${file}.sh
  if {[catch {open $file_unix w} fh_unix]} {
    send_msg_id exportsim-Tcl-034 ERROR "failed to open file to write ($file_unix)\n"
    return 1
  }

  if { [xps_write_driver_script $simulator $fh_unix $dir] } {
    return 1
  }

  close $fh_unix
  xps_set_permissions $file_unix
  return 0
}

proc xps_set_permissions { file } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  if {$::tcl_platform(platform) == "unix"} {
    if {[catch {exec chmod a+x $file} error_msg] } {
      send_msg_id exportsim-Tcl-036 WARNING "failed to change file permissions to executable ($file): $error_msg\n"
    }
  } else {
    if {[catch {exec attrib /D -R $file} error_msg] } {
      send_msg_id USF-XSim-070 WARNING "Failed to change file permissions to executable ($file): $error_msg\n"
    }
  }
}
 
proc xps_write_driver_script { simulator fh_unix launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  xps_write_main_driver_procs $simulator $fh_unix

  if { ({ies} == $simulator) || ({vcs} == $simulator) } {
    if { $a_sim_vars(b_single_step) } {
      # no do file required
    } else {
      xps_create_ies_vcs_do_file $simulator $launch_dir
    }
  }

  xps_write_simulator_procs $simulator $fh_unix $launch_dir

  puts $fh_unix "\n# Launch script"
  puts $fh_unix "run \$1 \$2"
  return 0
}

proc xps_write_main_driver_procs { simulator fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:
  xps_write_header $simulator $fh_unix
  xps_write_main $fh_unix
  xps_write_setup $simulator $fh_unix
  #xps_write_glbl $fh_unix
  xps_write_reset $simulator $fh_unix
  xps_write_run_steps $simulator $fh_unix
  xps_write_libs_unix $simulator $fh_unix
}

proc xps_write_simulator_procs { simulator fh_unix launch_dir } { 
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars

  set srcs_dir [xps_create_srcs_dir $launch_dir]

  if { $a_sim_vars(b_single_step) } {
    xps_write_single_step $simulator $fh_unix $launch_dir $srcs_dir
  } else {
    xps_write_multi_step $simulator $fh_unix $launch_dir $srcs_dir
    if { {ies} == $simulator } {
      xps_write_single_step_for_irun $launch_dir $srcs_dir
    }
  }
}

proc xps_write_single_step { simulator fh_unix launch_dir srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars

  puts $fh_unix "# RUN_STEP: <execute>"
  puts $fh_unix "execute()\n\{"

  switch -regexp -- $simulator {
    "xsim" {
      xps_write_prj_single_step $launch_dir $srcs_dir
      xps_write_xelab_cmdline $fh_unix $launch_dir
      #xps_write_xsim_cmdline $fh_unix $launch_dir
    }
    "modelsim" {
      puts $fh_unix "  source run.do 2>&1 | tee -a run.log"
      xps_write_do_file_for_compile $simulator $launch_dir $srcs_dir
    }
    "questa" {
      set filename "run.f"
      puts $fh_unix "  XILINX_VIVADO=$::env(XILINX_VIVADO)"
      puts $fh_unix "  export XILINX_VIVADO"
      set arg_list [list]
      xps_append_config_opts arg_list "questa" "qverilog"
      lappend arg_list   "-f $filename"
      #foreach filelist [xps_get_secureip_filelist] {
      #  lappend arg_list $filelist
      #}
      set install_path $::env(XILINX_VIVADO)
      lappend arg_list "-f $install_path/data/secureip/secureip_cell.list.f" \
                       "-y $install_path/data/verilog/src/retarget/" \
                       "+libext+.v" \
                       "-y $install_path/data/verilog/src/unisims/" \
                       "+libext+.v" \
                       "-l run.log" \
                       "glbl.v"
      #"-R -do \"run 1000ns; quit\""
      set prefix_ref_dir "true"
      set uniq_dirs [list]
      foreach dir [concat [xps_get_verilog_incl_dirs $simulator $launch_dir $prefix_ref_dir] [xps_get_verilog_incl_file_dirs $simulator $launch_dir $prefix_ref_dir]] {
        if { [lsearch -exact $uniq_dirs $dir] == -1 } {
          lappend uniq_dirs $dir
          lappend arg_list "\"+incdir+$dir\""
        }
      }
      set cmd_str [join $arg_list " \\\n       "]
      puts $fh_unix "  qverilog $cmd_str"

      set fh_1 0
      set file [file normalize [file join $launch_dir $filename]]
      if {[catch {open $file w} fh_1]} {
        send_msg_id exportsim-Tcl-037 ERROR "failed to open file to write ($file)\n"
        return 1
      }
      xps_write_compile_order $simulator $fh_1 $launch_dir $srcs_dir
      close $fh_1
    }
    "ies" {
      set filename "run.f"
      set arg_list [list]
      puts $fh_unix "  XILINX_VIVADO=$::env(XILINX_VIVADO)"
      puts $fh_unix "  export XILINX_VIVADO"
      set b_verilog_only 0
      if { [xps_contains_verilog] && ![xps_contains_vhdl] } {
        set b_verilog_only 1
      }
      xps_append_config_opts arg_list "ies" "irun"
      if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list end "-64bit"] }

      set install_path $::env(XILINX_VIVADO)

      lappend arg_list  "-timescale 1ps/1ps"
      set opts [list]
      set defines [get_property verilog_define [get_filesets $a_sim_vars(fs_obj)]]
      set generics [get_property vhdl_generic [get_filesets $a_sim_vars(fs_obj)]]
      if { [llength $defines] > 0 } {
        xps_append_define_generics $defines "irun" opts
      }
      if { [llength $generics] > 0 } {
        xps_append_define_generics $generics "irun" opts
      }
      if { [llength $opts] > 0 } {
        foreach opt $opts {
          set opt_str [string trim $opt "\{\}"]
          lappend arg_list  "$opt_str"
        }
      }
      lappend arg_list  "-top $a_sim_vars(s_top)" \
                        "-f $filename"
      if { $b_verilog_only } {
        lappend arg_list   "-f $install_path/data/secureip/secureip_cell.list.f"
      }
      if { [xps_contains_verilog] } {
        lappend arg_list "-top glbl"
        lappend arg_list "glbl.v"
      }
      if { $b_verilog_only } {
        lappend arg_list   "-y $install_path/data/verilog/src/retarget/" \
                           "+libext+.v" \
                           "-y $install_path/data/verilog/src/unisims/" \
                           "+libext+.v"
      }
      if { $a_sim_vars(b_xport_src_files) } {
        lappend arg_list "+incdir+\"srcs/incl\""
      } else {
        set prefix_ref_dir "false"
        set uniq_dirs [list]
        foreach dir [concat [xps_get_verilog_incl_dirs $simulator $launch_dir $prefix_ref_dir] [xps_get_verilog_incl_file_dirs $simulator $launch_dir $prefix_ref_dir]] {
          if { [lsearch -exact $uniq_dirs $dir] == -1 } {
            lappend uniq_dirs $dir
            lappend arg_list "+incdir+\"$dir\""
          }
        }
      }
      lappend arg_list   "-l run.log"

      set cmd_str [join $arg_list " \\\n       "]
      puts $fh_unix "  irun $cmd_str"
      set fh_1 0
      set file [file normalize [file join $launch_dir $filename]]
      if {[catch {open $file w} fh_1]} {
        send_msg_id exportsim-Tcl-038 ERROR "failed to open file to write ($file)\n"
        return 1
      }
      xps_write_compile_order $simulator $fh_1 $launch_dir $srcs_dir
      close $fh_1
    }
    "vcs" {
      set filename "run.f"
      puts $fh_unix "  XILINX_VIVADO=$::env(XILINX_VIVADO)"
      puts $fh_unix "  export XILINX_VIVADO"
      set arg_list [list]
      xps_append_config_opts arg_list "vcs" "vcs"

      set install_path $::env(XILINX_VIVADO)

      lappend arg_list   "-V" \
                         "-timescale=1ps/1ps" \
                         "-f $filename" \
                         "-f $install_path/data/secureip/secureip_cell.list.f"
      if { [xps_contains_verilog] } {
        lappend arg_list "glbl.v"
      }
      lappend arg_list   "+libext+.v" \
                         "-y $install_path/data/verilog/src/retarget/" \
                         "+libext+.v" \
                         "-y $install_path/data/verilog/src/unisims/" \
                         "+libext+.v" \
                         "-lca -v2005 +v2k"

      if { [xps_contains_system_verilog] } {
        lappend args_list "-sverilog"
      }

      lappend arg_list "-l run.log"
      set prefix_ref_dir "true"
      set uniq_dirs [list]
      foreach dir [concat [xps_get_verilog_incl_dirs $simulator $launch_dir $prefix_ref_dir] [xps_get_verilog_incl_file_dirs $simulator $launch_dir $prefix_ref_dir]] {
        if { {vcs} == $simulator } {
          set dir [string trim $dir "\""]
          regsub -all { } $dir {\\\\ } dir
        }
        if { [lsearch -exact $uniq_dirs $dir] == -1 } {
          lappend uniq_dirs $dir
          lappend arg_list "+incdir+\"$dir\""
        }
      }
      lappend arg_list "-R"
      set cmd_str [join $arg_list " \\\n       "]
      puts $fh_unix "  vcs $cmd_str"
      #puts $fh_unix "  ./simv"
  
      set fh_1 0
      set file [file normalize [file join $launch_dir $filename]]
      if {[catch {open $file w} fh_1]} {
        send_msg_id exportsim-Tcl-039 ERROR "failed to open file to write ($file)\n"
        return 1
      }
      xps_write_compile_order $simulator $fh_1 $launch_dir $srcs_dir
      close $fh_1
    }
  }
  puts $fh_unix "\}\n"
  return 0
}

proc xps_write_single_step_for_irun { launch_dir srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set fh 0
  set filename "filelist_irun.f"
  set file [file normalize [file join $launch_dir $filename]]
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-038 ERROR "failed to open file to write ($file)\n"
    return 1
  }
  set a_sim_vars(b_single_step) 1
  xps_write_compile_order "ies" $fh $launch_dir $srcs_dir
  set a_sim_vars(b_single_step) 0
  close $fh
}

proc xps_write_multi_step { simulator fh_unix launch_dir srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  puts $fh_unix "\n# RUN_STEP: <compile>"
  puts $fh_unix "compile()\n\{"

  if { ({ies} == $simulator) || ({vcs} == $simulator) } {
    xps_write_ref_dir $fh_unix $launch_dir $srcs_dir
  }

  if {[llength $a_sim_vars(l_design_files)] == 0} {
    puts $fh_unix "  # None (no simulation source files found)"
    puts $fh_unix "  echo -e \"INFO: No simulation source file(s) to compile\\n\""
    puts $fh_unix "  exit 0"
    puts $fh_unix "\}"
    return 0
  }
  
  switch -regexp -- $simulator {
    "modelsim" -
    "questa" {
    }
    default {
      puts $fh_unix "  # Command line options"
    }
  }

  switch -regexp -- $simulator {
    "xsim" {
      set arg_list [list]
      xps_append_config_opts arg_list "xsim" "xvlog"
      if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-m64"] }
      if { [xps_contains_verilog] } {
        puts $fh_unix "  opts_ver=\"[join $arg_list " "]\""
      }
      set arg_list [list]
      xps_append_config_opts arg_list "xsim" "xvhdl"
      if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-m64"] }
      if { [xps_contains_vhdl] } {
        puts $fh_unix "  opts_vhd=\"[join $arg_list " "]\""
      }
    }
    "ies" { 
      set arg_list [list]
      xps_append_config_opts arg_list "ies" "ncvlog"
      set arg_list [linsert $arg_list end "-messages" "-logfile" "ncvlog.log" "-append_log"]
      if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-64bit"] }
      puts $fh_unix "  opts_ver=\"[join $arg_list " "]\""

      set arg_list [list]
      xps_append_config_opts arg_list "ies" "ncvhdl"
      set arg_list [linsert $arg_list end "-RELAX" "-logfile" "ncvhdl.log" "-append_log"]
      if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-64bit"] }
      puts $fh_unix "  opts_vhd=\"[join $arg_list " "]\""
    }
    "vcs"   {
      set arg_list [list]
      xps_append_config_opts arg_list "vcs" "vlogan"
      if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-full64"] }
      puts $fh_unix "  opts_ver=\"[join $arg_list " "]\""

      set arg_list [list]
      xps_append_config_opts arg_list "vcs" "vhdlan"
      if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-full64"] }
      puts $fh_unix "  opts_vhd=\"[join $arg_list " "]\""
    }
  }

  puts $fh_unix "\n  # Compile design files" 

  switch $simulator { 
    "xsim" {
      set redirect "2>&1 | tee compile.log"
      if { [xps_contains_verilog] } {
        puts $fh_unix "  xvlog \$opts_ver -prj vlog.prj $redirect"
      }
      if { [xps_contains_vhdl] } {
        puts $fh_unix "  xvhdl \$opts_vhd -prj vhdl.prj $redirect"
      }
      xps_write_xsim_prj $launch_dir $srcs_dir
    }
    "modelsim" -
    "questa" {
      puts $fh_unix "  source compile.do 2>&1 | tee -a compile.log"
      xps_write_do_file_for_compile $simulator $launch_dir $srcs_dir
    }
    "ies" -
    "vcs" {
      xps_write_compile_order $simulator $fh_unix $launch_dir $srcs_dir
    }
  }
   
  if { [xps_contains_verilog] } {
    set top_lib [xps_get_top_library]
    switch -regexp -- $simulator {
      "ies" {
        puts $fh_unix "\n  ncvlog \$opts_ver -work $top_lib \\\n\    \"glbl.v\""
      }
      "vcs" {
        set sw {}
        if { {work} != $top_lib } {
          set sw "-work $top_lib"
        }
        puts $fh_unix "  vlogan $sw \$opts_ver +v2k \\\n    glbl.v \\\n  2>&1 | tee -a vlogan.log"
      }
    }
  }

  puts $fh_unix "\n\}\n"

  switch -regexp -- $simulator {
    "modelsim" {}
    default {
      xps_write_elaboration_cmds $simulator $fh_unix $launch_dir
    }
  }
  xps_write_simulation_cmds $simulator $fh_unix $launch_dir

  xps_print_usage $fh_unix

  return 0
}

proc xps_append_config_opts { opts_arg simulator tool } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
  set opts_str {}
  switch -exact -- $simulator {
    "xsim" {
      if {"xvlog" == $tool} {set opts_str "--relax"}
      if {"xvhdl" == $tool} {set opts_str "--relax"}
      if {"xelab" == $tool} {set opts_str "--relax --debug typical --mt auto"}
      if {"xsim"  == $tool} {set opts_str ""}
    }
    "modelsim" {
      if {"vlog" == $tool} {set opts_str "-incr"}
      if {"vcom" == $tool} {set opts_str "-93"}
      if {"vsim" == $tool} {set opts_str ""}
    }
    "questa" {
      if {"vlog"     == $tool} {set opts_str ""}
      if {"vcom"     == $tool} {set opts_str ""}
      if {"vopt"     == $tool} {set opts_str ""}
      if {"vsim"     == $tool} {set opts_str ""}
      if {"qverilog" == $tool} {set opts_str "-incr +acc"}
    }
    "ies" {
      if {"ncvlog" == $tool} {set opts_str ""}
      if {"ncvhdl" == $tool} {set opts_str "-V93"}
      if {"ncelab" == $tool} {set opts_str "-relax -access +rwc -messages"}
      if {"ncsim"  == $tool} {set opts_str ""}
      if {"irun"   == $tool} {set opts_str "-V93 -RELAX"}
    }
    "vcs" {
      if {"vlogan" == $tool} {set opts_str "-timescale=1ps/1ps"}
      if {"vhdlan" == $tool} {set opts_str ""}
      if {"vcs"    == $tool} {set opts_str ""}
      if {"simv"   == $tool} {set opts_str ""}
    }
  }
  if { {} != $opts_str } {
    lappend opts $opts_str
  }
}

proc xps_write_ref_dir { fh_unix launch_dir srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  set txt "  # Directory path for design sources and include directories (if any) wrt this path"
  if { $a_sim_vars(b_absolute_path) } {
    if { $a_sim_vars(b_xport_src_files) } {
      puts $fh_unix "$txt"
      puts $fh_unix "  ref_dir=\"$srcs_dir\""
    }
  } else {
    puts $fh_unix "$txt"
    if { $a_sim_vars(b_xport_src_files) } {
      puts $fh_unix "  ref_dir=\"srcs\""
    } else {
      puts $fh_unix "  ref_dir=\".\""
    }
  }
}

proc xps_write_run_steps { simulator fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  puts $fh_unix "# Main steps"
  puts $fh_unix "run()\n\{"
  puts $fh_unix "  setup \$1 \$2"
  if { $a_sim_vars(b_single_step) } {
    puts $fh_unix "  execute"
  } else {
    puts $fh_unix "  compile"
    switch -regexp -- $simulator {
      "modelsim" {}
      default {
        puts $fh_unix "  elaborate"
      }
    }
    puts $fh_unix "  simulate"
  }
  puts $fh_unix "\}\n"
}

proc xps_remove_duplicate_files { compile_order_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set file_list [list]
  set compile_order [list]
  foreach file $compile_order_files {
    set normalized_file_path [file normalize [string map {\\ /} $file]]
    if { [lsearch -exact $file_list $normalized_file_path] == -1 } {
      lappend file_list $normalized_file_path
      lappend compile_order $file
    }
  }
  return $compile_order
}

proc xps_set_initial_cmd { simulator fh cmd_str src_file file_type lib opts_str prev_file_type_arg prev_lib_arg log_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:
  # None

  variable a_sim_vars
  upvar $prev_file_type_arg prev_file_type
  upvar $prev_lib_arg  prev_lib
  upvar $log_arg log
  switch $simulator {
    "xsim" {
      if { $a_sim_vars(b_single_step) } {
       # 
      } else {
        puts $fh "$cmd_str \\"
        if { $a_sim_vars(b_xport_src_files) } {
          puts $fh "srcs/$src_file ${opts_str} \\"
        } else {
          puts $fh "$src_file ${opts_str} \\"
        }
      }
    }
    "modelsim" -
    "questa" {
      puts $fh "$cmd_str \\"
      puts $fh "$src_file \\"
    }
    "ies" {
      if { $a_sim_vars(b_single_step) } {
        puts $fh "-makelib ies/$lib \\"
        if { $a_sim_vars(b_xport_src_files) } {
          puts $fh "  srcs/$src_file \\"
        } else {
          puts $fh "  $src_file \\"
        }
      } else {
        puts $fh "  $cmd_str \\"
        if { $a_sim_vars(b_xport_src_files) } {
          puts $fh "    \$ref_dir/$src_file \\"
        } else {
          puts $fh "    $src_file \\"
        }
      }
    }
    "vcs" {
      puts $fh "  $cmd_str \\"
      if { $a_sim_vars(b_xport_src_files) } {
        puts $fh "    \$ref_dir/$src_file \\"
      } else {
        puts $fh "    $src_file \\"
      }
    }
  }
  set prev_file_type $file_type
  set prev_lib  $lib
  switch $simulator {
    "vcs" {
      if { [regexp -nocase {vhdl} $file_type] } {
        set log "vhdlan.log"
      } elseif { [regexp -nocase {verilog} $file_type] } {
        set log "vlogan.log"
      }
    }
  }
}

# multi-step (ies/vcs), single-step (questa, ies, vcs) 
proc xps_write_compile_order { simulator fh launch_dir srcs_dir } {
  # Summary: Write compile order for the target simulator
  # Argument Usage:
  # fh - file handle
  # Return Value:
  # none
 
  variable a_sim_vars

  set b_first true
  set prev_lib  {}
  set prev_file_type {}
  set log {}
  set redirect_cmd_str "  2>&1 | tee -a"
  set b_redirect false
  set b_appended false

  foreach file $a_sim_vars(l_design_files) {
    set fargs          [split $file {|}]
    set type           [lindex $fargs 0]
    set file_type      [lindex $fargs 1]
    set lib            [lindex $fargs 2]
    set proj_src_file  [lindex $fargs 3]
    set cmd_str        [lindex $fargs 4]
    set ip_file        [lindex $fargs 5]
    set src_file       [lindex $fargs 6]
    set b_static_ip    [lindex $fargs 7]

    if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }

    if { $a_sim_vars(b_absolute_path) } {
      switch $simulator {
        "questa" {
          if { $a_sim_vars(b_xport_src_files) } {
            set source_file {}
            if { {} != $ip_file } {
              set proj_src_filename [file tail $proj_src_file]
              set ip_name [file rootname [file tail $ip_file]]
              set proj_src_filename "ip/$ip_name/$proj_src_filename"
              set source_file "srcs/$proj_src_filename"
            } else {
              set source_file "srcs/[file tail $proj_src_file]"
            }
            set src_file "\"$source_file\""
          }
        }
      }
    } else {
      switch $simulator {
        "questa" {
          if { $a_sim_vars(b_xport_src_files) } {
            set source_file {}
            if { {} != $ip_file } {
              set proj_src_filename [file tail $proj_src_file]
              set ip_name [file rootname [file tail $ip_file]]
              set proj_src_filename "ip/$ip_name/$proj_src_filename"
              set source_file "srcs/$proj_src_filename"
            } else {
              set source_file "srcs/[file tail $proj_src_file]"
            }
            set src_file "\"$source_file\""
          } else {
            if { {} != $ip_file } {
              # no op
            } else {
              set source_file [string trim $src_file {\"}]
              set src_file "[xps_get_relative_file_path $source_file $launch_dir]"
              set src_file "\"$src_file\""
            }
          }
        }
        "ies" {
          if { $a_sim_vars(b_xport_src_files) } {
            set source_file "\$ref_dir/incl"
            if { {} != $ip_file } {
              # no op
            } else {
            }
          } else {
            if { {} != $ip_file } {
              set source_file [string trim $src_file {\"}]
              set src_file "\$ref_dir/$source_file"
              if { $a_sim_vars(b_single_step) } {
                set src_file "$source_file"
              }
              set src_file "\"$src_file\""
            } else {
              set source_file [string trim $src_file {\"}]
              set src_file "\$ref_dir/[xps_get_relative_file_path $source_file $launch_dir]"
              if { $a_sim_vars(b_single_step) } {
                set src_file "[xps_get_relative_file_path $proj_src_file $launch_dir]"
              }
              set src_file "\"$src_file\""
            }
          }
        }
        "vcs" {
          if { $a_sim_vars(b_xport_src_files) } {
            set source_file "\$ref_dir/incl"
            if { {} != $ip_file } {
              # no op
            } else {
            }
          } else {
            if { {} != $ip_file } {
              set source_file [string trim $src_file {\"}]
              if { $a_sim_vars(b_single_step) } {
                set src_file "$source_file"
              } else {
                set src_file "\$ref_dir/$source_file"
                #set src_file "\$ref_dir/[xps_get_relative_file_path $source_file $launch_dir]"
                set src_file "\"$src_file\""
              }
            } else {
              set source_file [string trim $src_file {\"}]
              if { $a_sim_vars(b_single_step) } {
                set src_file "[xps_get_relative_file_path $source_file $launch_dir]"
              } else {
                set src_file "\$ref_dir/[xps_get_relative_file_path $source_file $launch_dir]"
                set src_file "\"$src_file\""
              }
            }
          }
        }
      }
    }
    set proj_src_filename [file tail $proj_src_file]
    if { $a_sim_vars(b_xport_src_files) } {
      set target_dir $srcs_dir
      if { {} != $ip_file } {
        set ip_name [file rootname [file tail $ip_file]]
        set proj_src_filename "ip/$ip_name/$proj_src_filename"
        set ip_dir [file join $srcs_dir "ip" $ip_name] 
        if { ![file exists $ip_dir] } {
          if {[catch {file mkdir $ip_dir} error_msg] } {
            send_msg_id exportsim-Tcl-040 ERROR "failed to create the directory ($ip_dir): $error_msg\n"
            return 1
          }
        }
        set target_dir $ip_dir
      }
      if { [get_param project.enableCentralSimRepo] } {
        if { $a_sim_vars(b_xport_src_files) } {
          if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
            send_msg_id exportsim-Tcl-041 WARNING "failed to copy file '$proj_src_file' to '$srcs_dir' : $error_msg\n"
          }
        } else { 
          set repo_file $src_file
          set repo_file [string trim $repo_file "\""]
          if {[catch {file copy -force $repo_file $target_dir} error_msg] } {
            send_msg_id exportsim-Tcl-051 WARNING "failed to copy file '$repo_file' to '$srcs_dir' : $error_msg\n"
          }
        }
      } else {
        if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
          send_msg_id exportsim-Tcl-041 WARNING "failed to copy file '$proj_src_file' to '$srcs_dir' : $error_msg\n"
        }
      }
    }
   
    switch $simulator {
      "vcs" {
        # vlogan expects double back slash
        if { ([regexp { } $src_file] && [regexp -nocase {vlogan} $cmd_str]) } {
          set src_file [string trim $src_file "\""]
          regsub -all { } $src_file {\\\\ } src_file
        }
      }
    }

    if { $a_sim_vars(b_single_step) } {
      switch $simulator {
        "ies" { }
        default {
          if { ([get_param project.enableCentralSimRepo]) } {
            set file $src_file
          } else {
            set file $proj_src_file
            regsub -all {\"} $file {} file

            if { $a_sim_vars(b_absolute_path) } {
              set file "[xps_resolve_file_path $file $launch_dir]"
            } else {
              set file "[xps_get_relative_file_path $file $launch_dir]"
            }
            if { $a_sim_vars(b_xport_src_files) } {
              set file "srcs/$proj_src_filename"
            }
          }
          puts $fh $file
          continue
        }
      }
    }

    set b_redirect false
    set b_appended false
    if { $b_first } {
      set b_first false
      if { $a_sim_vars(b_xport_src_files) } {
        xps_set_initial_cmd $simulator $fh $cmd_str $proj_src_filename $file_type $lib {} prev_file_type prev_lib log
      } else {
        xps_set_initial_cmd $simulator $fh $cmd_str $src_file $file_type $lib {} prev_file_type prev_lib log
      }
    } else {
      if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
        # single_step
        if { $a_sim_vars(b_single_step) } {
          if { $a_sim_vars(b_xport_src_files) } {
            switch $simulator {
              "ies" {
                puts $fh "  srcs/$proj_src_filename \\"
              }
              "vcs" {
                puts $fh "    srcs/$proj_src_filename \\"
              }
            }
          } else {
            switch $simulator {
              "ies" {
                puts $fh "  $src_file \\"
              }
              "vcs" {
                puts $fh "    $proj_src_file \\"
              }
            }
          }
        } else {
          if { $a_sim_vars(b_xport_src_files) } {
            switch $simulator {
              "ies" {
                puts $fh "    \$ref_dir/$proj_src_filename \\"
              }
              "vcs" {
                puts $fh "    \$ref_dir/$proj_src_filename \\"
              }
            }
          } else {
            switch $simulator {
              "ies" {
                puts $fh "    $src_file \\"
              }
              "vcs" {
                puts $fh "    $src_file \\"
              }
            }
          }
        }
        set b_redirect true
      } else {
        switch $simulator {
          "ies" { 
            if { $a_sim_vars(b_single_step) } {
              puts $fh "-endlib"
            } else {
              puts $fh ""
            }
          }
          "vcs"    { puts $fh "$redirect_cmd_str $log\n" }
        }
        if { $a_sim_vars(b_xport_src_files) } {
          xps_set_initial_cmd $simulator $fh $cmd_str $proj_src_filename $file_type $lib {} prev_file_type prev_lib log
        } else {
          xps_set_initial_cmd $simulator $fh $cmd_str $src_file $file_type $lib {} prev_file_type prev_lib log
        }
        set b_appended true
      }
    }
  }

  if { $a_sim_vars(b_single_step) } {
    switch $simulator {
      "ies" { 
        puts $fh "-endlib"
      }
    }
  } else {
    switch $simulator {
      "vcs" {
        if { (!$b_redirect) || (!$b_appended) } {
          puts $fh "$redirect_cmd_str $log\n"
        }
      }
    }
  }

  if { [xps_contains_verilog] } {
    if { $a_sim_vars(b_single_step) } { 
      switch -regexp -- $simulator {
        "ies" {
          puts $fh "-makelib ies/xil_defaultlib \\"
          puts $fh "  glbl.v"
          puts $fh "-endlib"
        }
      }
    }
  }
  # do not remove this
  puts $fh ""

}

proc xps_write_header { simulator fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:
  # none
 
  variable a_sim_vars
 
  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 2]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]
  set extn ".sh"
  set script_file $a_sim_vars(s_script_filename)$extn
  puts $fh_unix "#!/bin/bash -f"
  puts $fh_unix "# $product (TM) $version_id\n#"
  puts $fh_unix "# Filename    : $a_sim_vars(s_script_filename)$extn"
  puts $fh_unix "# Simulator   : [xps_get_simulator_pretty_name $simulator]"
  puts $fh_unix "# Description : Simulation script for compiling, elaborating and verifying the project source files."
  puts $fh_unix "#               The script will automatically create the design libraries sub-directories in the run"
  puts $fh_unix "#               directory, add the library logical mappings in the simulator setup file, create default"
  puts $fh_unix "#               'do/prj' file, execute compilation, elaboration and simulation steps.\n#"
  puts $fh_unix "# Generated by $product on $a_sim_vars(curr_time)"
  puts $fh_unix "# $copyright \n#"
  puts $fh_unix "# usage: $script_file \[-help\]"
  puts $fh_unix "# usage: $script_file \[-lib_map_path\]"
  puts $fh_unix "# usage: $script_file \[-noclean_files\]"
  puts $fh_unix "# usage: $script_file \[-reset_run\]\n#"
  switch -regexp -- $simulator {
    "xsim" {
    }
    default {
      puts $fh_unix "# Prerequisite:- To compile and run simulation, you must compile the Xilinx simulation libraries using the"
      puts $fh_unix "# 'compile_simlib' TCL command. For more information about this command, run 'compile_simlib -help' in the"
      puts $fh_unix "# $product Tcl Shell. Once the libraries have been compiled successfully, specify the -lib_map_path switch"
      puts $fh_unix "# that points to these libraries and rerun export_simulation. For more information about this switch please"
      puts $fh_unix "# type 'export_simulation -help' in the Tcl shell.\n#"
      puts $fh_unix "# You can also point to the simulation libraries by either replacing the <SPECIFY_COMPILED_LIB_PATH> in this"
      puts $fh_unix "# script with the compiled library directory path or specify this path with the '-lib_map_path' switch when"
      puts $fh_unix "# executing this script. Please type '$script_file -help' for more information.\n#"
      puts $fh_unix "# Additional references - 'Xilinx Vivado Design Suite User Guide:Logic simulation (UG900)'\n#"
    }
  }
  puts $fh_unix "# ********************************************************************************************************\n"
}

proc xps_write_elaboration_cmds { simulator fh_unix dir} {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  set top $a_sim_vars(s_top)

  puts $fh_unix "# RUN_STEP: <elaborate>"
  puts $fh_unix "elaborate()\n\{"

  if {[llength $a_sim_vars(l_design_files)] == 0} {
    puts $fh_unix "# None (no sources present)"
    return 0
  }
 
  switch -regexp -- $simulator {
    "xsim" {
      xps_write_xelab_cmdline $fh_unix $dir
    }
    "modelsim" -
    "questa" {
      puts $fh_unix "  source elaborate.do 2>&1 | tee -a elaborate.log"
      xps_write_do_file_for_elaborate $simulator $dir
    }
    "ies" { 
      set top_lib [xps_get_top_library]
      set arg_list [list]
      xps_append_config_opts arg_list "ies" "ncelab"
      set arg_list [linsert $arg_list end "-logfile" "elaborate.log" "-timescale 1ps/1ps"]
      if { ! $a_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-64bit"]
      }
      # design contains ax-bfm ip? insert bfm library
      if { [xps_is_axi_bfm_ip] } {
        set simulator_lib [xps_get_bfm_lib $simulator]
        if { {} != $simulator_lib } {
          set arg_list [linsert $arg_list 0 "-loadvpi \"$simulator_lib:xilinx_register_systf\""]
        } else {
          send_msg_id exportsim-Tcl-020 "CRITICAL WARNING" \
            "Failed to locate the simulator library from 'XILINX_VIVADO' environment variable. Library does not exist.\n"
        }
      }
      puts $fh_unix "  opts=\"[join $arg_list " "]\""
      set arg_list [list]
      if { [xps_contains_verilog] } {
        lappend arg_list "-libname unisims_ver"
        lappend arg_list "-libname unimacro_ver"
      }
      lappend arg_list "-libname secureip"
      foreach lib [xps_get_compile_order_libs] {
        if {[string length $lib] == 0} { continue; }
        lappend arg_list "-libname"
        lappend arg_list "[string tolower $lib]"
      }
      puts $fh_unix "  libs=\"[join $arg_list " "]\""

      set arg_list [list "ncelab" "\$opts"]
      if { [xps_is_fileset $a_sim_vars(sp_tcl_obj)] } {
        set vhdl_generics [list]
        set vhdl_generics [get_property vhdl_generic [get_filesets $a_sim_vars(fs_obj)]]
        if { [llength $vhdl_generics] > 0 } {
          xps_append_define_generics $vhdl_generics "ncelab" arg_list
        }
      }
      lappend arg_list "${top_lib}.$a_sim_vars(s_top)"
      if { [xps_contains_verilog] } {
        lappend arg_list "${top_lib}.glbl"
      }
      lappend arg_list "\$libs"
      set cmd_str [join $arg_list " "]
      puts $fh_unix "  $cmd_str"
    }
    "vcs" {
      set top_lib [xps_get_top_library]
      set arg_list [list]
      xps_append_config_opts arg_list "vcs" "vcs"
      set arg_list [linsert $arg_list end "-debug_pp" "-t" "ps" "-licqueue" "-l" "elaborate.log"]
      if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-full64"] }
      # design contains ax-bfm ip? insert bfm library
      if { [xps_is_axi_bfm_ip] } {
        set simulator_lib [xps_get_bfm_lib $simulator]
        if { {} != $simulator_lib } {
          set arg_list [linsert $arg_list 0 "-load \"$simulator_lib:xilinx_register_systf\""]
        } else {
          send_msg_id exportsim-Tcl-020 "CRITICAL WARNING" \
            "Failed to locate the simulator library from 'XILINX_VIVADO' environment variable. Library does not exist.\n"
        }
      }
      puts $fh_unix "  opts=\"[join $arg_list " "]\"\n"
      set arg_list [list "vcs" "\$opts" "${top_lib}.$a_sim_vars(s_top)"]
      if { [xps_is_fileset $a_sim_vars(sp_tcl_obj)] } {
        set vhdl_generics [list]
        set vhdl_generics [get_property vhdl_generic [get_filesets $a_sim_vars(fs_obj)]]
        if { [llength $vhdl_generics] > 0 } {
          xps_append_define_generics $vhdl_generics "vcs" arg_list
        }
      }
      if { [xps_contains_verilog] } {
        lappend arg_list "${top_lib}.glbl"
      }
      lappend arg_list "-o"
      lappend arg_list "$a_sim_vars(s_top)_simv"
      set cmd_str [join $arg_list " "]
      puts $fh_unix "  $cmd_str"
    }
  }
  puts $fh_unix "\}\n"
  return 0
}
 
proc xps_write_simulation_cmds { simulator fh_unix dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars

  puts $fh_unix "# RUN_STEP: <simulate>"
  puts $fh_unix "simulate()\n\{"
  if {[llength $a_sim_vars(l_design_files)] == 0} {
    puts $fh_unix "# None (no sources present)"
    return 0
  }
 
  switch -regexp -- $simulator {
    "xsim" {
      xps_write_xsim_cmdline $fh_unix $dir
    }
    "modelsim" -
    "questa" {
      set cmd_str "vsim -64 -c -do \"do \{$a_sim_vars(do_filename)\}\" -l simulate.log"
      puts $fh_unix "  $cmd_str"
      xps_write_do_file_for_simulate $simulator $dir
    }
    "ies" { 
      set top_lib [xps_get_top_library]
      set arg_list [list "-logfile" "simulate.log"]
      if { !$a_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-64bit"]
      }
      puts $fh_unix "  opts=\"[join $arg_list " "]\""
      set arg_list [list]
      lappend arg_list "ncsim"
      xps_append_config_opts arg_list $simulator "ncsim"
      lappend arg_list "\$opts" "${top_lib}.$a_sim_vars(s_top)" "-input" "$a_sim_vars(do_filename)"
      set cmd_str [join $arg_list " "]
      puts $fh_unix "  $cmd_str"
    }
    "vcs" {
      set arg_list [list]
      xps_append_config_opts arg_list $simulator "simv"
      lappend arg_list "-ucli" "-licqueue" "-l" "simulate.log"
      puts $fh_unix "  opts=\"[join $arg_list " "]\""
      puts $fh_unix ""
      set arg_list [list "./$a_sim_vars(s_top)_simv" "\$opts" "-do" "$a_sim_vars(do_filename)"]
      set cmd_str [join $arg_list " "]
      puts $fh_unix "  $cmd_str"
    }
  }
  puts $fh_unix "\}"
  return 0
}

proc xps_create_udo_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # if udo file exists, return
  if { [file exists $file] } {
    return 0
  }
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-044 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
  close $fh
}

proc xps_find_files { src_files_arg filter dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  upvar $src_files_arg src_files

  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xps_is_ip $tcl_obj] } {
    set ip_name [file tail $tcl_obj]
    foreach file [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $filter] {
      if { [lsearch -exact [list_property $file] {IS_USER_DISABLED}] != -1 } {
        if { [get_property {IS_USER_DISABLED} $file] } {
          continue;
        }
      }
      set file [file normalize $file]
      if { $a_sim_vars(b_absolute_path) } {
        set file "[xps_resolve_file_path $file $dir]"
      } else {
        set file "[xps_get_relative_file_path $file $dir]"
      }
      lappend src_files $file
    }
  } elseif { [xps_is_fileset $tcl_obj] } {
    set filesets       [list]

    lappend filesets $a_sim_vars(fs_obj)
    set linked_src_set {}
    if { ({SimulationSrcs} == [get_property fileset_type $a_sim_vars(fs_obj)]) } {
      set linked_src_set [get_property "SOURCE_SET" $a_sim_vars(fs_obj)]
    }
    if { {} != $linked_src_set } {
      lappend filesets $linked_src_set
    }

    # add block filesets
    set blk_filter "FILESET_TYPE == \"BlockSrcs\""
    foreach blk_fs_obj [get_filesets -filter $blk_filter] {
      lappend filesets $blk_fs_obj
    }

    foreach fs_obj $filesets {
      foreach file [get_files -quiet -of_objects [get_filesets $fs_obj] -filter $filter] {
        if { [lsearch -exact [list_property $file] {IS_USER_DISABLED}] != -1 } {
          if { [get_property {IS_USER_DISABLED} $file] } {
            continue;
          }
        }
        set file [file normalize $file]
        if { $a_sim_vars(b_absolute_path) } {
          set file "[xps_resolve_file_path $file $dir]"
        } else {
          set file "[xps_get_relative_file_path $file $dir]"
        }
        lappend src_files $file
      }
    }
  }
}

proc xps_append_define_generics { def_gen_list tool opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
  foreach element $def_gen_list {
    set key_val_pair [split $element "="]
    set name [lindex $key_val_pair 0]
    set val  [lindex $key_val_pair 1]
    set str {}
    switch $tool {
      "vlog"   { set str "+define+$name="       }
      "ncvlog" -
      "irun"   { set str "-define \"$name=\""   }
      "vlogan" { set str "+define+$name="     }
      "ncelab" -
      "ies"    { set str "-generic \"$name=>\"" }
      "vcs"    { set str "-gv $name=\""         }
    }

    if { [string length $val] > 0 } {
      if { {vlog} == $tool } {
        if { [regexp {'} $val] } {
          regsub -all {'} $val {\\'} val
        }
      }
    }

    if { [string length $val] > 0 } {
      switch $tool {
        "vlog"   { set str "$str$val"   }
        "ncvlog" -
        "irun"   { set str "$str$val\"" }
        "vlogan" { set str "$str\"$val\"" }
        "ncelab" -
        "ies"    { set str "$str$val\"" }
        "vcs"    { set str "$str$val\"" }
      }
    }
    lappend opts "$str"
  }
}

proc xps_append_define_generics_1 { def_gen_list tool opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
  foreach element $def_gen_list {
    set key_val_pair [split $element "="]
    set name [lindex $key_val_pair 0]
    set val  [lindex $key_val_pair 1]
    if { [string length $val] > 0 } {
      if { {vlog} == $tool } {
        if { [regexp {'} $val] } {
          regsub -all {'} $val {\\'} val
        }
      }
      switch $tool {
        "vlog"   { lappend opts "+define+$name=$val"       }
        "ncvlog" { lappend opts "-define \"$name=$val\""   }
        "vlogan" { lappend opts "+define+\"$name=$val\""   }
        "ncelab" -
        "ies"    { lappend opts "-generic \"$name=>$val\"" }
        "vcs"    { lappend opts "-gv $name=\"$val\""       }
      }
    }
  }
}

proc xps_get_compiler { simulator file_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set compiler ""
  if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } {
    switch -regexp -- $simulator {
      "xsim"     { set compiler "vhdl" }
      "modelsim" -
      "questa"   { set compiler "vcom" }
      "ies"      { set compiler "ncvhdl" }
      "vcs"      { set compiler "vhdlan" }
    }
  } elseif { ({Verilog} == $file_type) || ({SystemVerilog} == $file_type) || ({Verilog Header} == $file_type) } {
    switch -regexp -- $simulator {
      "xsim"     {
        set compiler "verilog"
        if { {SystemVerilog} == $file_type } {
          set compiler "sv"
        }
      }
      "modelsim" -
      "questa"   { set compiler "vlog" }
      "ies"      { set compiler "ncvlog" }
      "vcs"      { set compiler "vlogan" }
    }
  }
  return $compiler
}
 
proc xps_append_compiler_options { simulator launch_dir tool file_type l_verilog_incl_dirs_arg opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $l_verilog_incl_dirs_arg l_verilog_incl_dirs
  upvar $opts_arg opts
  variable a_sim_vars
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  switch $tool {
    "vcom" {
      set s_64bit {-64}
      set arg_list [list $s_64bit]
      #lappend arg_list "-93"
      xps_append_config_opts arg_list $simulator "vcom"
      set cmd_str [join $arg_list " "]
      lappend opts $cmd_str
    }
    "vlog" {
      set s_64bit {-64}
      set arg_list [list $s_64bit]
      xps_append_config_opts arg_list $simulator "vlog"
      set cmd_str [join $arg_list " "]
      lappend opts $cmd_str
      if { [string equal -nocase $file_type "systemverilog"] } {
        lappend opts "-sv"
      }
    }
    "ncvhdl" { 
       lappend opts "\$opts_vhd"
    }
    "vhdlan" {
       lappend opts "\$opts_vhd"
    }
    "ncvlog" {
      lappend opts "\$opts_ver"
      if { [string equal -nocase $file_type "systemverilog"] } {
        lappend opts "-sv"
      }
    }
    "vlogan" {
      lappend opts "\$opts_ver"
      if { [string equal -nocase $file_type "verilog"] } {
        lappend opts "+v2k"
      } elseif { [string equal -nocase $file_type "systemverilog"] } {
        lappend opts "-sverilog"
      }
    }
  }

  # append verilog defines, include dirs and include file dirs
  switch $tool {
    "vlog" -
    "ncvlog" -
    "vlogan" {
      # verilog defines
      set verilog_defines [list]
      set verilog_defines [get_property verilog_define [get_filesets $a_sim_vars(fs_obj)]]
      if { [llength $verilog_defines] > 0 } {
        xps_append_define_generics $verilog_defines $tool opts
      }
 
      # include dirs
      set prefix_ref_dir "true"
      set uniq_dirs [list]
      foreach dir $l_verilog_incl_dirs {
        if { {vlogan} == $tool } {
          set dir [string trim $dir "\""]
          regsub -all { } $dir {\\\\ } dir
        }
        if { [lsearch -exact $uniq_dirs $dir] == -1 } {
          lappend uniq_dirs $dir
          if { ({questa} == $simulator) || ({modelsim} == $simulator) } {
            lappend opts "\"+incdir+$dir\""
          } else {
            lappend opts "+incdir+\"$dir\""
          }
        }
      }
    }
  }
}
 
proc xps_get_compile_order_libs { } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  set libs [list]
  foreach file $a_sim_vars(l_design_files) {
    set library   [lindex [split $file {|}] 2]
    if { {} == $library } {
      continue;
    }
    if { [lsearch -exact $libs $library] == -1 } {
      lappend libs $library
    }
  }

  return $libs
}

proc xps_get_top_library { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set tcl_obj $a_sim_vars(sp_tcl_obj)

  set src_mgmt_mode         [get_property "SOURCE_MGMT_MODE" [current_project]]
  set manual_compile_order  [expr {$src_mgmt_mode != "All"}]

  # was -of_objects <ip> specified?, fetch current fileset
  if { [xps_is_ip $tcl_obj] } {
    set tcl_obj $a_sim_vars(fs_obj)
  }

  # 1. get the default top library set for the project
  set default_top_library [get_property "DEFAULT_LIB" [current_project]]

  # 2. get the library associated with the top file from the 'top_lib' property on the fileset
  set fileset_top_library [get_property "TOP_LIB" [get_filesets $tcl_obj]]

  # 3. get the library associated with the last file in compile order
  set co_top_library {}
  set filelist [xps_get_compile_order_files]
  if { [llength $filelist] > 0 } {
    set file_list [get_files -quiet -all [list "[lindex $filelist end]"]]
    if { [llength $file_list] > 0 } {
      set co_top_library [get_property "LIBRARY" [lindex $file_list 0]]
    }
  }

  # 4. if default top library is set and the compile order file library is different
  #    than this default, return the compile order file library
  if { {} != $default_top_library } {
    # manual compile order, we just return the file set's top
    if { $manual_compile_order && ({} != $fileset_top_library) } {
      return $fileset_top_library
    }
    # compile order library is set and is different then the default
    if { ({} != $co_top_library) && ($default_top_library != $co_top_library) } {
      return $co_top_library
    } else {
      # worst case (default is set but compile order file library is empty or we failed to get the library for some reason)
      return $default_top_library
    }
  }

  # 5. default top library is empty at this point
  #    if fileset top library is set and the compile order file library is different
  #    than this default, return the compile order file library
  if { {} != $fileset_top_library } {
    # manual compile order, we just return the file set's top
    if { $manual_compile_order } {
      return $fileset_top_library
    }
    # compile order library is set and is different then the fileset
    if { ({} != $co_top_library) && ($fileset_top_library != $co_top_library) } {
      return $co_top_library
    } else {
      # worst case (fileset library is set but compile order file library is empty or we failed to get the library for some reason)
      return $fileset_top_library
    }
  }

  # 6. Both the default and fileset library are empty, return compile order library else xilinx default
  if { {} != $co_top_library } {
    return $co_top_library
  }

  return "xil_defaultlib"
}

proc xps_get_compile_order_files { } {
  # Summary:
  # Argument Usage:
  # Return Value:
  return [xps_uniquify_cmd_str $::tclapp::xilinx::projutils::l_compile_order_files]
}
 
proc xps_contains_verilog {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set design_files $a_sim_vars(l_design_files)
  set b_verilog_srcs 0
  foreach file $design_files {
    set type [lindex [split $file {|}] 0]
    switch $type {
      {VERILOG} {
        set b_verilog_srcs 1
      }
    }
  }
  return $b_verilog_srcs 
}

proc xps_contains_system_verilog {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set design_files $a_sim_vars(l_design_files)
  set b_sys_verilog_srcs 0
  foreach file $design_files {
    set type [lindex [split $file {|}] 1]
    if { {SystemVerilog} == $type } {
      set b_sys_verilog_srcs 1
    }
  }
  return $b_sys_verilog_srcs 
}

proc xps_contains_vhdl {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set design_files $a_sim_vars(l_design_files)
  set b_vhdl_srcs 0
  foreach file $design_files {
    set type [lindex [split $file {|}] 0]
    switch $type {
      {VHDL} -
      {VHDL 2008} {
        set b_vhdl_srcs 1
      }
    }
  }

  return $b_vhdl_srcs
}

proc xps_append_generics { generic_list opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
  foreach element $generic_list {
    set key_val_pair [split $element "="]
    set name [lindex $key_val_pair 0]
    set val  [lindex $key_val_pair 1]
    set str "-g$name="
    if { [string length $val] > 0 } {
      set str $str$val
    }
    lappend opts $str
  }
}

proc xps_verify_ip_status {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set regen_ip [dict create] 
  set b_single_ip 0
  if { ([xps_is_ip $a_sim_vars(sp_tcl_obj)]) && ({.xci} == $a_sim_vars(s_ip_file_extn)) } {
    set ip [file root [file tail $a_sim_vars(sp_tcl_obj)]]
    # is user-disabled? or auto_disabled? skip
    if { ({0} == [get_property is_enabled [get_files -quiet -all ${ip}.xci]]) ||
         ({1} == [get_property is_auto_disabled [get_files -quiet -all ${ip}.xci]]) } {
      return
    }
    dict set regen_ip $ip d_targets [get_property delivered_targets [get_ips -all -quiet $ip]]
    dict set regen_ip $ip s_targets [get_property supported_targets [get_ips -all -quiet $ip]]
    dict set regen_ip $ip generated [get_property is_ip_generated [get_ips -all -quiet $ip]]
    dict set regen_ip $ip generated_sim [get_property is_ip_generated_sim [lindex [get_files -all -quiet ${ip}.xci] 0]]
    dict set regen_ip $ip stale [get_property stale_targets [get_ips -all -quiet $ip]]
    set b_single_ip 1
  } else {
    foreach ip [get_ips -all -quiet] {
      # is user-disabled? or auto_disabled? continue
      if { ({0} == [get_property is_enabled [get_files -quiet -all ${ip}.xci]]) ||
           ({1} == [get_property is_auto_disabled [get_files -quiet -all ${ip}.xci]]) } {
        continue
      }
      dict set regen_ip $ip d_targets [get_property delivered_targets [get_ips -all -quiet $ip]]
      dict set regen_ip $ip s_targets [get_property supported_targets [get_ips -all -quiet $ip]]
      dict set regen_ip $ip generated [get_property is_ip_generated $ip]
      dict set regen_ip $ip generated_sim [get_property is_ip_generated_sim [lindex [get_files -all -quiet ${ip}.xci] 0]]
      dict set regen_ip $ip stale [get_property stale_targets $ip]
    }
  } 

  set not_generated [list]
  set stale_ips [list]
  dict for {ip regen} $regen_ip {
    dic with regen {
      if { {} == $d_targets } {
        continue
      }
      if { [lsearch $s_targets "simulation"] == -1 } {
        continue
      }
      if { {0} == $generated_sim } {
        lappend not_generated $ip
      } else {
        if { [llength $stale] > 0 } {
          lappend stale_ips $ip
        }
      }
    }
  }

  if { ([llength $not_generated] > 0 ) || ([llength $stale_ips] > 0) } {
    set txt [list]
    foreach ip $not_generated { lappend txt "Status - (Not Generated) IP NAME = $ip" }
    foreach ip $stale_ips     { lappend txt "Status - (Out of Date)   IP NAME = $ip" }
    set msg_txt [join $txt "\n"]
    if { $b_single_ip } {
      send_msg_id exportsim-Tcl-045 "CRITICAL WARNING" \
         "The '$ip' IP have not generated output products yet or have subsequently been updated, making the current\n\
         output products out-of-date. It is strongly recommended that this IP be re-generated and then this script run again to get a complete output.\n\
         To generate the output products please see 'generate_target' Tcl command.\n\
         $msg_txt"
    } else {
      send_msg_id exportsim-Tcl-045 "CRITICAL WARNING" \
         "The following IPs have not generated output products yet or have subsequently been updated, making the current\n\
         output products out-of-date. It is strongly recommended that these IPs be re-generated and then this script run again to get a complete output.\n\
         To generate the output products please see 'generate_target' Tcl command.\n\
         $msg_txt"
    }
  }
}

proc xps_print_usage { fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  puts $fh_unix "# Script usage"
  puts $fh_unix "usage()"
  puts $fh_unix "\{"
  puts $fh_unix "  msg=\"Usage: $a_sim_vars(s_script_filename).sh \[-help\]\\n\\"
  puts $fh_unix "Usage: $a_sim_vars(s_script_filename).sh \[-lib_map_path\]\\n\\"
  puts $fh_unix "Usage: $a_sim_vars(s_script_filename).sh \[-reset_run\]\\n\\"
  puts $fh_unix "Usage: $a_sim_vars(s_script_filename).sh \[-noclean_files\]\\n\\n\\"
  puts $fh_unix "\[-help\] -- Print help information for this script\\n\\n\\"
  puts $fh_unix "\[-lib_map_path\ <path>] -- Compiled simulation library directory path. The simulation library is compiled\\n\\"
  puts $fh_unix "using the compile_simlib tcl command. Please see 'compile_simlib -help' for more information.\\n\\n\\"
  puts $fh_unix "\[-reset_run\] -- Recreate simulator setup files and library mappings for a clean run. The generated files\\n\\"
  puts $fh_unix "from the previous run will be removed. If you don't want to remove the simulator generated files, use the\\n\\"
  puts $fh_unix "-noclean_files switch.\\n\\n\\"
  puts $fh_unix "\[-noclean_files\] -- Reset previous run, but do not remove simulator generated files from the previous run.\\n\\n\""
  puts $fh_unix "  echo -e \$msg"
  puts $fh_unix "  exit 1"
  puts $fh_unix "\}"
  puts $fh_unix ""
}

proc xps_write_libs_unix { simulator fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  switch $simulator {
    "xsim" {
      if { $a_sim_vars(b_use_static_lib) } {
        puts $fh_unix "# Copy xsim.ini file"
        puts $fh_unix "copy_setup_file()"
        puts $fh_unix "\{"
        puts $fh_unix "  file=\"xsim.ini\""
      }
    }
    "modelsim" -
    "questa" {
      puts $fh_unix "# Copy modelsim.ini file"
      puts $fh_unix "copy_setup_file()"
      puts $fh_unix "\{"
      puts $fh_unix "  file=\"modelsim.ini\""
    }
    "ies" -
    "vcs" {
      puts $fh_unix "# Create design library directory paths and define design library mappings in cds.lib"
      puts $fh_unix "create_lib_mappings()"
      puts $fh_unix "\{"
      set libs [list]
      foreach lib [xps_get_compile_order_libs] {
        if {[string length $lib] == 0} { continue; }
        if { ({work} == $lib) && ({vcs} == $simulator) } { continue; }
        if { $a_sim_vars(b_use_static_lib) && ([xps_is_static_ip_lib $lib]) } {
          # no op
        } else {
          lappend libs [string tolower $lib]
        }
      }
      puts $fh_unix "  libs=([join $libs " "])"
      switch -regexp -- $simulator {
        "ies"      { puts $fh_unix "  file=\"cds.lib\"" }
        "vcs"      { puts $fh_unix "  file=\"synopsys_sim.setup\"" }
      }
      puts $fh_unix "  dir=\"$simulator\"\n"
      puts $fh_unix "  if \[\[ -e \$file \]\]; then"
      puts $fh_unix "    rm -f \$file"
      puts $fh_unix "  fi\n"
      puts $fh_unix "  if \[\[ -e \$dir \]\]; then"
      puts $fh_unix "    rm -rf \$dir"
      puts $fh_unix "  fi"
      puts $fh_unix ""
      puts $fh_unix "  touch \$file"
    }
  }

  if { {xsim} == $simulator } {
    if { $a_sim_vars(b_use_static_lib) } {
      set compiled_lib_dir {}
      set b_path_exist false
      # is -lib_map_path specified and point to valid location?
      if { [string length $a_sim_vars(s_lib_map_path)] > 0 } {
        set a_sim_vars(s_lib_map_path) [file normalize $a_sim_vars(s_lib_map_path)]
        set compiled_lib_dir $a_sim_vars(s_lib_map_path)
        if { [file exists $compiled_lib_dir] } {
          set b_path_exist true
          puts $fh_unix "  if \[\[ (\$1 != \"\") \]\]; then"
          puts $fh_unix "    lib_map_path=\"\$1\""
          puts $fh_unix "  else"
          puts $fh_unix "    lib_map_path=\"$compiled_lib_dir\""
          puts $fh_unix "  fi"
        }
      }
      
      if { ! $b_path_exist } {
        puts $fh_unix "  lib_map_path=\"<SPECIFY_COMPILED_LIB_PATH>\""
        puts $fh_unix "  if \[\[ (\$1 != \"\" && -e \$1) \]\]; then"
        puts $fh_unix "    lib_map_path=\"\$1\""
        puts $fh_unix "  else"
        puts $fh_unix "    echo -e \"ERROR: Compiled simulation library directory path not specified or does not exist (type \"./top.sh -help\" for more information)\\n\""
        puts $fh_unix "  fi"
      }
    }
  } else {
    # is -lib_map_path specified and point to valid location?
    if { [string length $a_sim_vars(s_lib_map_path)] > 0 } {
      set a_sim_vars(s_lib_map_path) [file normalize $a_sim_vars(s_lib_map_path)]
      set compiled_lib_dir $a_sim_vars(s_lib_map_path)
      if { ![file exists $compiled_lib_dir] } {
        [catch {send_msg_id exportsim-Tcl-046 ERROR "Compiled simulation library directory path does not exist:$compiled_lib_dir\n"}]
        puts $fh_unix "  lib_map_path=\"<SPECIFY_COMPILED_LIB_PATH>\""
        puts $fh_unix "  if \[\[ (\$1 != \"\" && -e \$1) \]\]; then"
        puts $fh_unix "    lib_map_path=\"\$1\""
        puts $fh_unix "  else"
        puts $fh_unix "    echo -e \"ERROR: Compiled simulation library directory path not specified or does not exist (type \"./top.sh -help\" for more information)\\n\""
        puts $fh_unix "  fi"
      } else {
        puts $fh_unix "  if \[\[ (\$1 != \"\") \]\]; then"
        puts $fh_unix "    lib_map_path=\"\$1\""
        puts $fh_unix "  else"
        puts $fh_unix "    lib_map_path=\"$compiled_lib_dir\""
        puts $fh_unix "  fi"
      }
    } else {
      set compiled_lib_dir {}
      if { {all} != $a_sim_vars(s_simulator) } {
        #xps_set_cxl_lib $simulator
      }
      set ini_file "modelsim.ini"
      switch -regexp -- $simulator {
        "modelsim" { set dir [get_property "COMPXLIB.MODELSIM_COMPILED_LIBRARY_DIR" [current_project]] }
        "questa"   { set dir [get_property "COMPXLIB.QUESTA_COMPILED_LIBRARY_DIR" [current_project]] }
        "ies"      { set dir [get_property "COMPXLIB.IES_COMPILED_LIBRARY_DIR" [current_project]];set ini_file "cds.lib" }
        "vcs"      { set dir [get_property "COMPXLIB.VCS_COMPILED_LIBRARY_DIR" [current_project]];set ini_file "synopsys_sim.setup" }
      }
      set file [file normalize [file join $dir $ini_file]]
      if { [file exists $file] } {
        set compiled_lib_dir $dir
      }
      
      if { {} != $compiled_lib_dir } {
        puts $fh_unix "  if \[\[ (\$1 != \"\") \]\]; then"
        puts $fh_unix "    lib_map_path=\"\$1\""
        puts $fh_unix "  else"
        puts $fh_unix "    lib_map_path=\"$compiled_lib_dir\""
        puts $fh_unix "  fi"
      } else {
        #send_msg_id exportsim-Tcl-047 WARNING \
        #   "The pre-compiled simulation library directory path was not specified (-lib_map_path), which may\n\
        #   cause simulation errors when running this script. Please refer to the generated script header section for more details."
        puts $fh_unix "  lib_map_path=\"<SPECIFY_COMPILED_LIB_PATH>\""
        puts $fh_unix "  if \[\[ (\$1 != \"\" && -e \$1) \]\]; then"
        puts $fh_unix "    lib_map_path=\"\$1\""
        puts $fh_unix "  else"
        puts $fh_unix "    echo -e \"ERROR: Compiled simulation library directory path not specified or does not exist (type \"./top.sh -help\" for more information)\\n\""
        puts $fh_unix "  fi"
      }
    }
  }
 
  switch -regexp -- $simulator {
    "xsim" {
      if { $a_sim_vars(b_use_static_lib) } {
        puts $fh_unix "  src_file=\"\$lib_map_path/\$file\""
        #puts $fh_unix "  if \[\[ ! -e \$file \]\]; then"
        puts $fh_unix "  cp \$src_file ."
        #puts $fh_unix "  fi"
        puts $fh_unix "\}\n"
      }
    }
    "modelsim" -
    "questa" {
      puts $fh_unix "  src_file=\"\$lib_map_path/\$file\""
      #puts $fh_unix "  if \[\[ ! -e \$file \]\]; then"
      puts $fh_unix "  cp \$src_file ."
      #puts $fh_unix "  fi"
      puts $fh_unix "\}\n"
    }
    "ies" {
      set file "cds.lib"
      if { $a_sim_vars(b_single_step) } {
        puts $fh_unix ""
        #puts $fh_unix "  echo \"INCLUDE \$lib_map_path/$file\" > \$file" 
        puts $fh_unix "  echo \"DEFINE secureip \$lib_map_path/secureip\" >> \$file"
        puts $fh_unix "  echo \"DEFINE unisim \$lib_map_path/unisim\" >> \$file"
        puts $fh_unix "  echo \"DEFINE unimacro \$lib_map_path/unimacro\" >> \$file"
        puts $fh_unix "  echo \"DEFINE unifast \$lib_map_path/unifast\" >> \$file"
        puts $fh_unix "  echo \"DEFINE unisims_ver \$lib_map_path/unisims_ver\" >> \$file"
        puts $fh_unix "  echo \"DEFINE unimacro_ver \$lib_map_path/unimacro_ver\" >> \$file"
        puts $fh_unix "  echo \"DEFINE unifast_ver \$lib_map_path/unifast_ver\" >> \$file"
      } else {
        puts $fh_unix "  incl_ref=\"INCLUDE \$lib_map_path/$file\""
        puts $fh_unix "  echo \$incl_ref >> \$file"
      }
    }
    "vcs" {
      set file "synopsys_sim.setup"
      puts $fh_unix "  incl_ref=\"OTHERS=\$lib_map_path/$file\""
      puts $fh_unix "  echo \$incl_ref >> \$file"
    }
  }

  switch -regexp -- $simulator {
    "ies" -
    "vcs" {
      puts $fh_unix ""
      puts $fh_unix "  for (( i=0; i<\$\{#libs\[*\]\}; i++ )); do"
      puts $fh_unix "    lib=\"\$\{libs\[i\]\}\""
      puts $fh_unix "    lib_dir=\"\$dir/\$lib\""
      puts $fh_unix "    if \[\[ ! -e \$lib_dir \]\]; then"
      puts $fh_unix "      mkdir -p \$lib_dir"
    }
  }

  switch -regexp -- $simulator {
    "ies"      { puts $fh_unix "      mapping=\"DEFINE \$lib \$dir/\$lib\"" }
    "vcs"      { puts $fh_unix "      mapping=\"\$lib : \$dir/\$lib\"" }
  }

  switch -regexp -- $simulator {
    "ies" -
    "vcs" {
      puts $fh_unix "      echo \$mapping >> \$file"
      puts $fh_unix "    fi"
      puts $fh_unix "  done"
      puts $fh_unix "\}"
      puts $fh_unix ""
    }
  }
}

proc xps_set_cxl_lib { simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars

  set simulator_id [string tolower $simulator]
  set old_param "simulator.compiled_library_dir"
  set old_prop  "compxlib.compiled_library_dir"
  
  set old_dir [get_property $old_prop [current_project]]
  set old_dir [file normalize $old_dir]
  set old_dir [string map {\\ /} $old_dir]
  #puts "old_param=$old_param"
  #puts "old_prop =$old_prop"
  #puts "old_dir  =$old_dir"

  set new_param "simulator.${simulator_id}_compiled_library_dir"
  set new_prop  "compxlib.${simulator_id}_compiled_library_dir"
  set new_dir   ""
  switch -regexp -- $simulator_id {
    "modelsim" { set new_dir [get_property compxlib.modelsim_compiled_library_dir [current_project]] }
    "questa"   { set new_dir [get_property compxlib.questa_compiled_library_dir   [current_project]] }
    "ies"      { set new_dir [get_property compxlib.ies_compiled_library_dir      [current_project]] }
    "vcs"      { set new_dir [get_property compxlib.vcs_compiled_library_dir      [current_project]] }
  }
  set new_dir [file normalize $new_dir]
  set new_dir [string map {\\ /} $new_dir]
  #puts "new_param=$new_param"
  #puts "new_prop =$new_prop"
  #puts "new_dir  =$new_dir"

  if { $old_dir != $new_dir } {
    set_property $new_prop $old_dir [current_project]
    #puts "set_property=$new_prop=$old_dir"
  }
  
  set old_param_lib_dir [get_param $old_param]
  if { {} != $old_param_lib_dir } {
    set old_param_lib_dir [file normalize $old_param_lib_dir]
    set old_param_lib_dir [string map {\\ /} $old_param_lib_dir]
  }

  set new_param_lib_dir [get_param $new_param]
  if { {} != $new_param_lib_dir } {
    set new_param_lib_dir [file normalize $new_param_lib_dir]
    set new_param_lib_dir [string map {\\ /} $new_param_lib_dir]
  }

  if { ({} != $old_param_lib_dir) || ({} != $new_param_lib_dir) } {
    if { {} == $new_param_lib_dir } {
      set_param $new_param $old_param_lib_dir
    }

    set param_lib_dir [get_param $new_param]
    if { {} != $param_lib_dir } {
      set param_lib_dir [file normalize $param_lib_dir]
      set param_lib_dir [string map {\\ /} $param_lib_dir]

      set b_cxl_prop 0
      if {$::tcl_platform(platform) == "unix"} {
        if { [string equal $old_dir $param_lib_dir] == 0 } {
          set b_cxl_prop 1
        }
      } else {
        if { [string equal -nocase $old_dir $param_lib_dir] == 0 } {
          set b_cxl_prop 1
        }
      }
    
      if { $b_cxl_prop } {

        set_property $old_prop $param_lib_dir [current_project]
        #puts "set_proprty=$old_prop=$param_lib_dir"
        set_property $new_prop $param_lib_dir [current_project]
        #puts "set_proprty=$new_prop=$param_lib_dir"

        #send_msg_id exportsim-Tcl-048 WARNING \
        #"The compiled library project property '$old_prop' is now set to '$param_lib_dir'. To reset this property back to its previous value '$old_dir', please set the '$old_param' param to an empty string and manually set the '$old_prop' property.\n"
      }
    }
  }
}

proc xps_create_ies_vcs_do_file { simulator dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set do_file [file join $dir $a_sim_vars(do_filename)]
  set fh_do 0
  if {[catch {open $do_file w} fh_do]} {
    send_msg_id exportsim-Tcl-048 ERROR "failed to open file to write ($do_file)\n"
  } else {
    set runtime "run"
    if { $a_sim_vars(b_runtime_specified) } {
      set runtime "run $a_sim_vars(s_runtime)"
    }
    switch -regexp -- $simulator {
      "ies"      {
        puts $fh_do "set pack_assert_off {numeric_std std_logic_arith}"
        puts $fh_do "\ndatabase -open waves -into waves.shm -default"
        puts $fh_do "probe -create -shm -all -variables -depth 1\n"
        puts $fh_do "$runtime"
        puts $fh_do "exit"
      }
      "vcs"      {
        puts $fh_do "$runtime"
        puts $fh_do "quit"
      }
    }
  }
  close $fh_do
}

proc xps_write_xsim_prj { dir srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set top $a_sim_vars(s_top)
  if { [xps_contains_verilog] } {
    set filename "vlog.prj"
    set file [file normalize [file join $dir $filename]]
    xps_write_prj $dir $file "VERILOG" $srcs_dir
  }

  if { [xps_contains_vhdl] } {
    set filename "vhdl.prj"
    set file [file normalize [file join $dir $filename]]
    xps_write_prj $dir $file "VHDL" $srcs_dir
  }
}

proc xps_write_prj { launch_dir file ft srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  set opts [list]
  if { {VERILOG} == $ft } {
    xps_get_xsim_verilog_options $launch_dir opts
  }
  set opts_str [join $opts " "]

  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-049 "Failed to open file to write ($file)\n"
    return 1
  }

  set log "compile.log"
  set b_first true
  set prev_lib  {}
  set prev_file_type {}
  set b_redirect false
  set b_appended false

  foreach file $a_sim_vars(l_design_files) {
    set fargs         [split $file {|}]
    set type          [lindex $fargs 0]
    set file_type     [lindex $fargs 1] 
    set lib           [lindex $fargs 2] 
    set proj_src_file [lindex $fargs 3]
    set cmd_str       [lindex $fargs 4]
    set ip_file       [lindex $fargs 5]
    set src_file      [lindex $fargs 6]
    set b_static_ip   [lindex $fargs 7]

    if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }

    if { $a_sim_vars(b_xport_src_files) } {
      set source_file {}
      if { {} != $ip_file } {
        set proj_src_filename [file tail $proj_src_file]
        set ip_name [file rootname [file tail $ip_file]]
        set proj_src_filename "ip/$ip_name/$proj_src_filename"
        set source_file "srcs/$proj_src_filename"
      } else {
        set source_file "srcs/[file tail $proj_src_file]"
        if { $a_sim_vars(b_absolute_path) } {
          set proj_src_filename [file tail $proj_src_file]
          set source_file "$srcs_dir/$proj_src_filename"
        }
      }
      set src_file "\"$source_file\""
    } else {
      if { {} != $ip_file } {
        # no op
      } else {
        set source_file [string trim $src_file {\"}]
        set src_file "[xps_get_relative_file_path $source_file $launch_dir]"
        if { $a_sim_vars(b_absolute_path) } {
          set src_file $proj_src_file 
        }
        set src_file "\"$src_file\""
      }
    }

    if { $ft == $type } {
      set proj_src_filename [file tail $proj_src_file]
      if { $a_sim_vars(b_xport_src_files) } {
        set target_dir $srcs_dir
        if { {} != $ip_file } {
          set ip_name [file rootname [file tail $ip_file]]
          set ip_dir [file join $srcs_dir "ip" $ip_name] 
          if { ![file exists $ip_dir] } {
            if {[catch {file mkdir $ip_dir} error_msg] } {
              send_msg_id exportsim-Tcl-050 ERROR "failed to create the directory ($ip_dir): $error_msg\n"
              return 1
            }
          }
          if { $a_sim_vars(b_absolute_path) } {
            set proj_src_filename "$ip_dir/$proj_src_filename"
          } else {
            set proj_src_filename "srcs/ip/$ip_name/$proj_src_filename"
          }
          set target_dir $ip_dir
        } else {
          if { $a_sim_vars(b_absolute_path) } {
            set proj_src_filename "$srcs_dir/$proj_src_filename"
          } else {
            set proj_src_filename "srcs/$proj_src_filename"
          }
        }
        if { ([get_param project.enableCentralSimRepo]) } {
          if { $a_sim_vars(b_xport_src_files) } {
            if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
              send_msg_id exportsim-Tcl-051 WARNING "failed to copy file '$proj_src_file' to '$srcs_dir' : $error_msg\n"
            }
          } else {
            set repo_file $src_file
            set repo_file [string trim $repo_file "\""]
            if {[catch {file copy -force $repo_file $target_dir} error_msg] } {
              send_msg_id exportsim-Tcl-051 WARNING "failed to copy file '$repo_file' to '$srcs_dir' : $error_msg\n"
            }
          }
        } else {
          if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
            send_msg_id exportsim-Tcl-051 WARNING "failed to copy file '$proj_src_file' to '$srcs_dir' : $error_msg\n"
          }
        }
      }

      if { $a_sim_vars(b_xport_src_files) } {
        puts $fh "$cmd_str $proj_src_filename ${opts_str}"
      } else {
        puts $fh "$cmd_str $src_file ${opts_str}"
      }
      # TODO: this does not work for verilog defines
      #if { $b_first } {
      #  set b_first false
      #  if { $a_sim_vars(b_xport_src_files) } {
      #    xps_set_initial_cmd "xsim" $fh $cmd_str $proj_src_filename $file_type $lib ${opts_str} prev_file_type prev_lib log
      #  } else {
      #    xps_set_initial_cmd "xsim" $fh $cmd_str $src_file $file_type $lib ${opts_str} prev_file_type prev_lib log
      #  }
      #} else {
      #  if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
      #    puts $fh "$src_file \\"
      #    set b_redirect true
      #  } else {
      #    puts $fh ""
      #    if { $a_sim_vars(b_xport_src_files) } {
      #      xps_set_initial_cmd "xsim" $fh $cmd_str $proj_src_filename $file_type $lib ${opts_str} prev_file_type prev_lib log
      #    } else {
      #      xps_set_initial_cmd "xsim" $fh $cmd_str $src_file $file_type $lib ${opts_str} prev_file_type prev_lib log
      #    }
      #    set b_appended true
      #  }
      #}
    }
  }

  if { {VERILOG} == $ft } {
    puts $fh "\nverilog [xps_get_top_library] \"glbl.v\""
  }
  puts $fh "\nnosort"

  close $fh
}

proc xps_write_prj_single_step { dir srcs_dir} {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  set filename "run.prj"
  set file [file normalize [file join $dir $filename]]
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-052 "Failed to open file to write ($file)\n"
    return 1
  }

  set opts [list]
  xps_get_xsim_verilog_options $dir opts
  set verilog_opts_str [join $opts " "]

  foreach file $a_sim_vars(l_design_files) {
    set fargs         [split $file {|}]
    set type          [lindex $fargs 0]
    set file_type     [lindex $fargs 1] 
    set lib           [lindex $fargs 2] 
    set proj_src_file [lindex $fargs 3]
    set cmd_str       [lindex $fargs 4]
    set ip_file       [lindex $fargs 5]
    set src_file      [lindex $fargs 6]

    set proj_src_filename [file tail $proj_src_file]
    if { $a_sim_vars(b_xport_src_files) } {
      set target_dir $srcs_dir
      if { {} != $ip_file } {
        set ip_name [file rootname [file tail $ip_file]]
        set proj_src_filename "ip/$ip_name/$proj_src_filename"
        set ip_dir [file join $srcs_dir "ip" $ip_name] 
        if { ![file exists $ip_dir] } {
          if {[catch {file mkdir $ip_dir} error_msg] } {
            send_msg_id exportsim-Tcl-053 ERROR "failed to create the directory ($ip_dir): $error_msg\n"
            return 1
          }
        }
        set target_dir $ip_dir
      } else {
        if { $a_sim_vars(b_absolute_path) } {
          set src_file "$srcs_dir/$proj_src_filename"
        } else {
          set proj_src_filename "srcs/$proj_src_filename"
        }
      }
      if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
        send_msg_id exportsim-Tcl-054 WARNING "failed to copy file '$proj_src_file' to '$srcs_dir' : $error_msg\n"
      }
    }
    if { {VERILOG} == $type } {
      puts $fh "$cmd_str $src_file ${verilog_opts_str}"
    } else {
      puts $fh "$cmd_str $src_file"
    }
  }
  if { [xps_contains_verilog] } {
    puts $fh "\nverilog [xps_get_top_library] \"glbl.v\""
  }
  puts $fh "\nnosort"

  close $fh
}

proc xps_get_xsim_verilog_options { launch_dir opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  upvar $opts_arg opts
  # include_dirs
  set unique_incl_dirs [list]
  set incl_dir_str [xps_resolve_incldir [get_property "INCLUDE_DIRS" [get_filesets $a_sim_vars(fs_obj)]]]
  foreach incl_dir [split $incl_dir_str "|"] {
    if { [lsearch -exact $unique_incl_dirs $incl_dir] == -1 } {
      lappend unique_incl_dirs $incl_dir
      if { $a_sim_vars(b_absolute_path) } {
        set incl_dir "[xps_resolve_file_path $incl_dir $launch_dir]"
      } else {
        set incl_dir "[xps_get_relative_file_path $incl_dir $launch_dir]"
      }
      lappend opts "-i \"$incl_dir\""
    }
  }

  # include dirs from design source set
  set linked_src_set [get_property "SOURCE_SET" [get_filesets $a_sim_vars(fs_obj)]]
  if { {} != $linked_src_set } {
    set src_fs_obj [get_filesets $linked_src_set]
    set incl_dir_str [xps_resolve_incldir [get_property "INCLUDE_DIRS" [get_filesets $src_fs_obj]]]
    foreach incl_dir [split $incl_dir_str "|"] {
      if { [lsearch -exact $unique_incl_dirs $incl_dir] == -1 } {
        lappend unique_incl_dirs $incl_dir
        if { $a_sim_vars(b_absolute_path) } {
          set incl_dir "[xps_resolve_file_path $incl_dir $launch_dir]"
        } else {
          set incl_dir "[xps_get_relative_file_path $incl_dir $launch_dir]"
        }
        lappend opts "-i \"$incl_dir\""
      }
    }
  }

  # --include
  set prefix_ref_dir "false"
  foreach incl_dir [xps_get_verilog_incl_file_dirs "xsim" $launch_dir $prefix_ref_dir] {
    set incl_dir [string map {\\ /} $incl_dir]
    lappend opts "--include \"$incl_dir\""
  }
  # -d (verilog macros)
  set v_defines [get_property "VERILOG_DEFINE" [get_filesets $a_sim_vars(fs_obj)]]
  if { [llength $v_defines] > 0 } {
    foreach element $v_defines {
      set key_val_pair [split $element "="]
      set name [lindex $key_val_pair 0]
      set val  [lindex $key_val_pair 1]
      set str "$name="
      if { [string length $val] > 0 } {
        set str "$str$val"
      }
      lappend opts "-d \"$str\""
    }
  }
}

# multi-step (modelsim and questa) and single-step (modelsim)
proc xps_write_do_file_for_compile { simulator dir srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set filename "compile.do"
  if { $a_sim_vars(b_single_step) } {
    set filename "run.do"
  }
  set do_file [file normalize [file join $dir $filename]]
  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id exportsim-Tcl-055 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }
  puts $fh "vlib work"
  puts $fh "vlib msim\n"
  set design_libs [xps_get_design_libs] 
  set b_default_lib false
  set default_lib [get_property "DEFAULT_LIB" [current_project]]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    if { $default_lib == $lib } {
      set b_default_lib true
    }
    set lib_path "msim/$lib"
    if { $a_sim_vars(b_use_static_lib) && ([xps_is_static_ip_lib $lib]) } {
      continue
    }
    puts $fh "vlib $lib_path"
  }
  if { !$b_default_lib } {
    puts $fh "vlib msim/$default_lib"
    puts $fh "vlib msim/$default_lib"
  }
  puts $fh ""
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    if { $a_sim_vars(b_use_static_lib) && ([xps_is_static_ip_lib $lib]) } {
      # no op
    } else {
      puts $fh "vmap $lib msim/$lib"
    }
  }
  if { !$b_default_lib } {
    puts $fh "vmap $default_lib msim/$default_lib"
  }
  puts $fh ""
  set log "compile.log"
  set b_first true
  set prev_lib  {}
  set prev_file_type {}
  set b_redirect false
  set b_appended false
  foreach file $a_sim_vars(l_design_files) {
    set fargs         [split $file {|}]
    set type          [lindex $fargs 0]
    set file_type     [lindex $fargs 1]
    set lib           [lindex $fargs 2]
    set proj_src_file [lindex $fargs 3]
    set cmd_str       [lindex $fargs 4]
    set ip_file       [lindex $fargs 5]
    set src_file      [lindex $fargs 6]
    set b_static_ip   [lindex $fargs 7]

    if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }

    if { $a_sim_vars(b_absolute_path) } {
      if { $a_sim_vars(b_xport_src_files) } {
        set source_file {}
        if { {} != $ip_file } {
          set proj_src_filename [file tail $proj_src_file]
          set ip_name [file rootname [file tail $ip_file]]
          set proj_src_filename "ip/$ip_name/$proj_src_filename"
          set source_file "srcs/$proj_src_filename"
        } else {
          set source_file "srcs/[file tail $proj_src_file]"
        }
        set src_file "\"$source_file\""
      }
    } else {
      if { $a_sim_vars(b_xport_src_files) } {
        set source_file {}
        if { {} != $ip_file } {
          set proj_src_filename [file tail $proj_src_file]
          set ip_name [file rootname [file tail $ip_file]]
          set proj_src_filename "ip/$ip_name/$proj_src_filename"
          set source_file "srcs/$proj_src_filename"
        } else {
          set source_file "srcs/[file tail $src_file]"
          set source_file [string trim $source_file {\"}]
        }
        set src_file "\"$source_file\""
      } else {
        if { {} != $ip_file } {
          # no op
        } else {
          set source_file [string trim $src_file {\"}]
          set src_file "[xps_get_relative_file_path $source_file $dir]"
          set src_file "\"$src_file\""
        }
      }
    }

    set proj_src_filename [file tail $proj_src_file]
    if { $a_sim_vars(b_xport_src_files) } {
      set target_dir $srcs_dir
      if { {} != $ip_file } {
        set ip_name [file rootname [file tail $ip_file]]
        set proj_src_filename "ip/$ip_name/$proj_src_filename"
        set ip_dir [file join $srcs_dir "ip" $ip_name] 
        if { ![file exists $ip_dir] } {
          if {[catch {file mkdir $ip_dir} error_msg] } {
            send_msg_id exportsim-Tcl-056 ERROR "failed to create the directory ($ip_dir): $error_msg\n"
            return 1
          }
        }
        #if { $a_sim_vars(b_absolute_path) } {
        #  set proj_src_filename "$ip_dir/$proj_src_filename"
        #}
        set target_dir $ip_dir
      }
      if { [get_param project.enableCentralSimRepo] } {
        if { $a_sim_vars(b_xport_src_files) } {
          if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
             send_msg_id exportsim-Tcl-051 WARNING "failed to copy file '$proj_src_file' to '$srcs_dir' : $error_msg\n"
          }
        } else {
          set repo_file $src_file
          set repo_file [string trim $repo_file "\""]
          if {[catch {file copy -force $repo_file $target_dir} error_msg] } {
            send_msg_id exportsim-Tcl-051 WARNING "failed to copy file '$repo_file' to '$srcs_dir' : $error_msg\n"
          }
        }
      } else {
        if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
          send_msg_id exportsim-Tcl-057 WARNING "failed to copy file '$proj_src_file' to '$srcs_dir' : $error_msg\n"
        }
      }
    }

    if { $b_first } {
      set b_first false
      xps_set_initial_cmd $simulator $fh $cmd_str $src_file $file_type $lib {} prev_file_type prev_lib log
    } else {
      if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
        puts $fh "$src_file \\"
        set b_redirect true
      } else {
        puts $fh ""
        xps_set_initial_cmd $simulator $fh $cmd_str $src_file $file_type $lib {} prev_file_type prev_lib log
        set b_appended true
      }
    }
  }

  if { (!$b_redirect) || (!$b_appended) } {
    puts $fh ""
  }

  # compile glbl file
  if { [xps_contains_verilog] } {
    puts $fh "\nvlog -work [xps_get_top_library] \"glbl.v\""
  }
  if { $a_sim_vars(b_single_step) } {
    set cmd_str [xps_get_simulation_cmdline_modelsim]
    puts $fh "\n$cmd_str"
  }

  # do not remove this
  puts $fh ""

  close $fh
}

proc xps_write_do_file_for_elaborate { simulator dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set filename "elaborate.do"
  set do_file [file normalize [file join $dir $filename]]
  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id exportsim-Tcl-058 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  switch $simulator {
    "modelsim" {
    }
    "questa" {
      set top_lib [xps_get_top_library]
      set arg_list [list "+acc" "-l" "elaborate.log"]
      if { !$a_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-64"]
      }
      set vhdl_generics [list]
      set vhdl_generics [get_property "GENERIC" [get_filesets $a_sim_vars(fs_obj)]]
      if { [llength $vhdl_generics] > 0 } {
        xps_append_generics $vhdl_generics arg_list
      }
      set t_opts [join $arg_list " "]
      set arg_list [list]
      if { [xps_contains_verilog] } {
        set arg_list [linsert $arg_list end "-L" "unisims_ver"]
        set arg_list [linsert $arg_list end "-L" "unimacro_ver"]
      }
      # add secureip
      set arg_list [linsert $arg_list end "-L" "secureip"]
      # add design libraries
      set design_libs [xps_get_design_libs]
      foreach lib $design_libs {
        if {[string length $lib] == 0} { continue; }
        lappend arg_list "-L"
        lappend arg_list "$lib"
      }
      set default_lib [get_property "DEFAULT_LIB" [current_project]]
      lappend arg_list "-work"
      lappend arg_list $default_lib
      set d_libs [join $arg_list " "]
      set top_lib [xps_get_top_library]
      set arg_list [list]
      lappend arg_list "vopt"
      xps_append_config_opts arg_list $simulator "vopt"
      lappend arg_list $t_opts
      lappend arg_list "$d_libs"
      set top $a_sim_vars(s_top)
      lappend arg_list "${top_lib}.$top"
      if { [xps_contains_verilog] } {
        lappend arg_list "${top_lib}.glbl"
      }
      lappend arg_list "-o"
      lappend arg_list "${top}_opt"
      set cmd_str [join $arg_list " "]
      puts $fh "$cmd_str"
    }
  }
  close $fh
}

proc xps_write_do_file_for_simulate { simulator dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set b_absolute_path $a_sim_vars(b_absolute_path)
  set filename $a_sim_vars(do_filename)
  set do_file [file normalize [file join $dir $filename]]
  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id exportsim-Tcl-059 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }
  set wave_do_filename "wave.do"
  set wave_do_file [file normalize [file join $dir $wave_do_filename]]
  xps_create_wave_do_file $wave_do_file
  set cmd_str {}
  switch $simulator {
    "modelsim" { set cmd_str [xps_get_simulation_cmdline_modelsim] }
    "questa"   { set cmd_str [xps_get_simulation_cmdline_questa] }
  }
  puts $fh "onbreak {quit -f}"
  puts $fh "onerror {quit -f}\n"
  puts $fh "$cmd_str"
  puts $fh "\ndo \{$wave_do_filename\}"
  puts $fh "\nview wave"
  puts $fh "view structure"
  puts $fh "view signals\n"
  set top $a_sim_vars(s_top)
  set udo_filename $top;append udo_filename ".udo"
  set udo_file [file normalize [file join $dir $udo_filename]]
  xps_create_udo_file $udo_file
  puts $fh "do \{$top.udo\}"
  set runtime "run -all"
  if { $a_sim_vars(b_runtime_specified) } {
    set runtime "run $a_sim_vars(s_runtime)"
  }
  puts $fh "\n$runtime"
  set tcl_src_files [list]
  set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"TCL\""
  xps_find_files tcl_src_files $filter $dir
  if {[llength $tcl_src_files] > 0} {
    puts $fh ""
    foreach file $tcl_src_files {
      puts $fh "source \{$file\}"
    }
    puts $fh ""
  }
  puts $fh "\nquit -force"
  close $fh
}

proc xps_create_wave_do_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  if { [file exists $file] } {
    return 0
  }
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id xps-Tcl-060 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
  puts $fh "add wave *"
  if { [xps_contains_verilog] } {
    puts $fh "add wave /glbl/GSR"
  }
  close $fh
}

proc xps_get_simulation_cmdline_modelsim {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set target_lang  [get_property "TARGET_LANGUAGE" [current_project]]
  set args [list]
  xps_append_config_opts args "modelsim" "vsim"
  #if { !$a_sim_vars(b_32bit) } {
  #  set args [linsert $args end "-64"]
  #}
  lappend args "-voptargs=\"+acc\"" "-t 1ps"
  if { $a_sim_vars(b_single_step) } {
    set args [linsert $args 1 "-c"]
  }
  if { $a_sim_vars(b_single_step) } {
    set runtime "run -all"
    if { $a_sim_vars(b_runtime_specified) } {
      set runtime "run $a_sim_vars(s_runtime)"
    }
    set args [linsert $args end "-do \"$runtime;quit -force\""]
  }
  set vhdl_generics [list]
  set vhdl_generics [get_property "GENERIC" [get_filesets $a_sim_vars(fs_obj)]]
  if { [llength $vhdl_generics] > 0 } {
    xps_append_generics $vhdl_generics args
  }
  if { [xps_is_axi_bfm_ip] } {
    set simulator_lib [xps_get_bfm_lib "modelsim"]
    if { {} != $simulator_lib } {
      set args [linsert $args end "-pli \"$simulator_lib\""]
    } else {
      send_msg_id exportsim-Tcl-020 "CRITICAL WARNING" \
        "Failed to locate the simulator library from 'XILINX_VIVADO' environment variable. Library does not exist.\n"
    }
  }
  set t_opts [join $args " "]
  set args [list]
  if { [xps_contains_verilog] } {
    set args [linsert $args end "-L" "unisims_ver"]
    set args [linsert $args end "-L" "unimacro_ver"]
  }
  set args [linsert $args end "-L" "secureip"]
  set design_libs [xps_get_design_libs]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    lappend args "-L"
    lappend args "$lib"
    #lappend args "[string tolower $lib]"
  }
  set default_lib [get_property "DEFAULT_LIB" [current_project]]
  lappend args "-lib"
  lappend args $default_lib
  set d_libs [join $args " "]
  set top_lib [xps_get_top_library]
  set args [list "vsim" $t_opts]
  lappend args "$d_libs"
  lappend args "${top_lib}.$a_sim_vars(s_top)"
  if { [xps_contains_verilog] } {
    lappend args "${top_lib}.glbl"
  }
  return [join $args " "]
}

proc xps_get_simulation_cmdline_questa {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set simulator "questa"
  set args [list]
  lappend args "vsim"
  xps_append_config_opts args "questa" "vsim"
  lappend args "-t 1ps"
  if { [xps_is_axi_bfm_ip] } {
    set simulator_lib [xps_get_bfm_lib $simulator]
    if { {} != $simulator_lib } {
      set args [linsert $args end "-pli \"$simulator_lib\""]
    } else {
      send_msg_id exportsim-Tcl-020 "CRITICAL WARNING" \
        "Failed to locate the simulator library from 'XILINX_VIVADO' environment variable. Library does not exist.\n"
    }
  }
  set default_lib [get_property "DEFAULT_LIB" [current_project]]
  lappend args "-lib"
  lappend args $default_lib
  lappend args "$a_sim_vars(s_top)_opt"
  set cmd_str [join $args " "]
  return $cmd_str
}

proc xps_write_xelab_cmdline { fh_unix launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set args [list "xelab"]
  xps_append_config_opts args "xsim" "xelab"
  lappend args "-wto [get_property ID [current_project]]"
  if { !$a_sim_vars(b_32bit) } { lappend args "-m64" }
  #set prefix_ref_dir "false"
  #foreach incl_dir [xps_get_verilog_incl_file_dirs "xsim" $launch_dir $prefix_ref_dir] {
  #  set dir [string map {\\ /} $incl_dir]
  #  lappend args "--include \"$dir\""
  #}
  #set unique_incl_dirs [list]
  #foreach incl_dir [get_property "INCLUDE_DIRS" $a_sim_vars(fs_obj)] {
  #  if { [lsearch -exact $unique_incl_dirs $incl_dir] == -1 } {
  #    lappend unique_incl_dirs $incl_dir
  #    lappend args "-i $incl_dir"
  #  }
  #}
  set v_defines [get_property "VERILOG_DEFINE" $a_sim_vars(fs_obj)]
  if { [llength $v_defines] > 0 } {
    foreach element $v_defines {
      set key_val_pair [split $element "="]
      set name [lindex $key_val_pair 0]
      set val  [lindex $key_val_pair 1]
      set str "$name="
      if { [string length $val] > 0 } {
        set str "$str$val"
      }
      lappend args "-d \"$str\""
    }
  }
  set v_generics [get_property "GENERIC" $a_sim_vars(fs_obj)]
  if { [llength $v_generics] > 0 } {
    foreach element $v_generics {
      set key_val_pair [split $element "="]
      set name [lindex $key_val_pair 0]
      set val  [lindex $key_val_pair 1]
      set str "$name="
      if { [string length $val] > 0 } {
        set str "$str$val"
      }
      lappend args "-generic_top \"$str\""
    }
  }
  set design_libs [xps_get_design_libs]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    lappend args "-L $lib"
  }
  if { [xps_contains_verilog] } {
    lappend args "-L unisims_ver"
    lappend args "-L unimacro_ver"
  }
  lappend args "-L secureip"
  lappend args "--snapshot [xps_get_snapshot]"
  foreach top [xps_get_tops] {
    lappend args "$top"
  }
  if { [xps_contains_verilog] } {
    if { ([lsearch [xps_get_tops] {glbl}] == -1) } {
      set top_lib [xps_get_top_library]
      lappend args "${top_lib}.glbl"
    }
  }
  if { $a_sim_vars(b_single_step) } {
    set filename "run.prj"
    lappend args "-prj $filename"
    lappend args "-R"
  }
  if { $a_sim_vars(b_single_step) } {
    lappend args "2>&1 | tee -a run.log"
  } else {
    lappend args "-log elaborate.log"
  }
  puts $fh_unix "  [join $args " "]"
}

proc xps_write_xsim_cmdline { fh_unix dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set args [list "xsim"]
  xps_append_config_opts args "xsim" "xsim"
  lappend args [xps_get_snapshot]
  lappend args "-key"
  lappend args "\{[xps_get_obj_key]\}"
  set cmd_file "cmd.tcl"
  if { $a_sim_vars(b_single_step) } {
    # 
  } else {
    xps_write_xsim_tcl_cmd_file $dir $cmd_file
  }
  lappend args "-tclbatch"
  lappend args "$cmd_file"
  if { $a_sim_vars(b_single_step) } {
    lappend args "2>&1 | tee -a run.log"
  } else {
    set log_file "simulate";append log_file ".log"
    lappend args "-log"
    lappend args "$log_file"
  }
  puts $fh_unix "  [join $args " "]"
}

proc xps_get_obj_key {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set mode "Behavioral"
  set fs_name [get_property "NAME" $a_sim_vars(fs_obj)]
  set flow_type "Functional"
  set key $mode;append key {:};append key $fs_name;append key {:};append key $flow_type;append key {:};append key $a_sim_vars(s_top)
  return $key
}

proc xps_write_xsim_tcl_cmd_file { dir filename } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set file [file normalize [file join $dir $filename]]
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-063 ERROR "Failed to open file to write ($file)\n"
    return 1
  }

  puts $fh "set curr_wave \[current_wave_config\]"
  puts $fh "if \{ \[string length \$curr_wave\] == 0 \} \{"
  puts $fh "  if \{ \[llength \[get_objects\]\] > 0\} \{"
  puts $fh "    add_wave /"
  puts $fh "    set_property needs_save false \[current_wave_config\]"
  puts $fh "  \} else \{"
  puts $fh "     send_msg_id Add_Wave-1 WARNING \"No top level signals found. Simulator will start without a wave window. If you want to open a wave window go to 'File->New Waveform Configuration' or type 'create_wave_config' in the TCL console.\""
  puts $fh "  \}"
  puts $fh "\}"
  set runtime "run -all"
  if { $a_sim_vars(b_runtime_specified) } {
    set runtime "run $a_sim_vars(s_runtime)"
  }
  puts $fh "\n$runtime"

  set tcl_src_files [list]
  set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"TCL\""
  xps_find_files tcl_src_files $filter $dir
  if {[llength $tcl_src_files] > 0} {
    puts $fh ""
    foreach file $tcl_src_files {
       puts $fh "source -notrace \{$file\}"
    }
    puts $fh ""
  }
  puts $fh "quit"
  close $fh
}

proc xps_resolve_uut_name { uut_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $uut_arg uut
  set uut [string map {\\ /} $uut]
  if { ![string match "/*" $uut] } {
    set uut "/$uut"
  }
  if { [string match "*/" $uut] } {
    set uut "${uut}*"
  }
  if { {/*} != [string range $uut end-1 end] } {
    set uut "${uut}/*"
  }
  return $uut
}

proc xps_get_tops {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set inst_names [list]
  set top $a_sim_vars(s_top)
  set top_lib [xps_get_top_library]
  set assoc_lib "${top_lib}";append assoc_lib {.}
  set top_names [split $top " "]
  if { [llength $top_names] > 1 } {
    foreach name $top_names {
      if { [lsearch $inst_names $name] == -1 } {
        if { ![regexp "^$assoc_lib" $name] } {
          set name ${assoc_lib}$name
        }
        lappend inst_names $name
      }
    }
  } else {
    set name $top_names
    if { ![regexp "^$assoc_lib" $name] } {
      set name ${assoc_lib}$name
    }
    lappend inst_names $name
  }
  return $inst_names
}

proc xps_get_snapshot {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set snapshot $a_sim_vars(s_top)
  return $snapshot
}

proc xps_write_glbl { fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set data_dir [rdi::get_data_dir -quiet -datafile verilog/src/glbl.v]
  set glbl_file [file normalize [file join $data_dir "verilog/src/glbl.v"]]

  puts $fh_unix "# Copy glbl.v file into run directory"
  puts $fh_unix "copy_glbl_file()"
  puts $fh_unix "\{"
  puts $fh_unix "  glbl_file=\"glbl.v\""
  puts $fh_unix "  src_file=\"$glbl_file\""
  puts $fh_unix "  if \[\[ ! -e \$glbl_file \]\]; then"
  puts $fh_unix "    cp \$src_file ."
  puts $fh_unix "  fi"
  puts $fh_unix "\}"
  puts $fh_unix ""
}

proc xps_write_reset { simulator fh_unix } {
  # Summary:
  # Argument Usage:
  # File handle
  # Return Value:
  # None 

  variable a_sim_vars

  set top $a_sim_vars(s_top)
  set file_list [list]
  set file_dir_list [list]
  set files [list]
  switch -regexp -- $simulator {
    "xsim" {
      set file_list [list "xelab.pb" "xsim.jou" "xvhdl.log" "xvlog.log" "compile.log" "elaborate.log" "simulate.log" \
                           "xelab.log" "xsim.log" "run.log" "xvhdl.pb" "xvlog.pb" "$a_sim_vars(s_top).wdb"]
      set file_dir_list [list "xsim.dir"]
    }
    "modelsim" -
    "questa" {
      set file_list [list "compile.log" "simulate.log" "vsim.wlf"]
      set file_dir_list [list "work" "msim"]
    }
    "ies" { 
      set file_list [list "ncsim.key" "irun.key" "ncvlog.log" "ncvhdl.log" "compile.log" "elaborate.log" "simulate.log" "run.log" "waves.shm"]
      set file_dir_list [list "INCA_libs"]
    }
    "vcs" {
      set file_list [list "ucli.key" "${top}_simv" \
                          "vlogan.log" "vhdlan.log" "compile.log" "elaborate.log" "simulate.log" \
                          ".vlogansetup.env" ".vlogansetup.args" ".vcs_lib_lock" "scirocco_command.log"]
      set file_dir_list [list "64" "AN.DB" "csrc" "${top}_simv.daidir"]
    }
  }
  set files [join $file_list " "]
  set files_dir [join $file_dir_list " "]

  puts $fh_unix "# Remove generated data from the previous run and re-create setup files/library mappings"
  puts $fh_unix "reset_run()"
  puts $fh_unix "\{"
  puts $fh_unix "  files_to_remove=($files $files_dir)"
  puts $fh_unix "  for (( i=0; i<\$\{#files_to_remove\[*\]\}; i++ )); do"
  puts $fh_unix "    file=\"\$\{files_to_remove\[i\]\}\""
  puts $fh_unix "    if \[\[ -e \$file \]\]; then"
  puts $fh_unix "      rm -rf \$file"
  puts $fh_unix "    fi"
  puts $fh_unix "  done"
  puts $fh_unix "\}"
  puts $fh_unix ""
}

proc xps_write_setup { simulator fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  set extn [string tolower [file extension $a_sim_vars(s_script_filename)]]
  puts $fh_unix "# STEP: setup"
  puts $fh_unix "setup()\n\{"
  puts $fh_unix "  case \$1 in"
  puts $fh_unix "    \"-lib_map_path\" )"
  puts $fh_unix "      if \[\[ (\$2 == \"\") \]\]; then"
  puts $fh_unix "        echo -e \"ERROR: Simulation library directory path not specified (type \\\"./$a_sim_vars(s_script_filename).sh -help\\\" for more information)\\n\""
  puts $fh_unix "        exit 1"
  puts $fh_unix "      fi"
  puts $fh_unix "      # precompiled simulation library directory path"
  switch -regexp -- $simulator {
    "xsim" {
      if { $a_sim_vars(b_use_static_lib) } {
        puts $fh_unix "     copy_setup_file \$2"
      }
    }
    "modelsim" -
    "questa" {
      puts $fh_unix "     copy_setup_file \$2"
    }
    "ies" -
    "vcs" {
      puts $fh_unix "     create_lib_mappings \$2"
    }
  }
  switch -regexp -- $simulator {
    "ies" { puts $fh_unix "     touch hdl.var" }
  }
  if { [xps_contains_verilog] } {
    #puts $fh_unix "     copy_glbl_file"
  }
  puts $fh_unix "    ;;"
  puts $fh_unix "    \"-reset_run\" )"
  puts $fh_unix "      reset_run"
  puts $fh_unix "      echo -e \"INFO: Simulation run files deleted.\\n\""
  puts $fh_unix "      exit 0"
  puts $fh_unix "    ;;"
  puts $fh_unix "    \"-noclean_files\" )"
  puts $fh_unix "      # do not remove previous data"
  puts $fh_unix "    ;;"
  puts $fh_unix "    * )"
  switch -regexp -- $simulator {
    "xsim" {
      if { $a_sim_vars(b_use_static_lib) } {
        puts $fh_unix "     copy_setup_file \$2"
      }
    }
    "modelsim" -
    "questa" {
      puts $fh_unix "     copy_setup_file \$2"
    }
    "ies" -
    "vcs" {
      puts $fh_unix "     create_lib_mappings \$2"
    }
  }
  switch -regexp -- $simulator {
    "ies" { puts $fh_unix "     touch hdl.var" }
  }
  if { [xps_contains_verilog] } {
    #puts $fh_unix "     copy_glbl_file"
  }
  puts $fh_unix "  esac"
  puts $fh_unix ""
  puts $fh_unix "  # Add any setup/initialization commands here:-\n"
  puts $fh_unix "  # <user specific commands>\n"
  puts $fh_unix "\}\n"
}

proc xps_write_main { fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 2]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]
  puts $fh_unix "# Script info"
  puts $fh_unix "echo -e \"$a_sim_vars(s_script_filename).sh - Script generated by export_simulation ($version-id)\\n\"\n"
  xps_print_usage $fh_unix
  #puts $fh_unix "# Check command line args"
  #puts $fh_unix "if \[\[ \$# > 1 \]\]; then"
  #puts $fh_unix "  echo -e \"ERROR: invalid number of arguments specified\\n\""
  #puts $fh_unix "  usage"
  #puts $fh_unix "fi\n"
  puts $fh_unix "if \[\[ (\$# == 1 ) && (\$1 != \"-lib_map_path\" && \$1 != \"-noclean_files\" && \$1 != \"-reset_run\" && \$1 != \"-help\" && \$1 != \"-h\") \]\]; then"
  puts $fh_unix "  echo -e \"ERROR: Unknown option specified '\$1' (type \\\"./$a_sim_vars(s_script_filename).sh -help\\\" for more information)\\n\""
  puts $fh_unix "  exit 1"
  puts $fh_unix "fi"
  puts $fh_unix ""
  puts $fh_unix "if \[\[ (\$1 == \"-help\" || \$1 == \"-h\") \]\]; then"
  puts $fh_unix "  usage"
  puts $fh_unix "fi\n"
}

proc xps_is_axi_bfm_ip {} {
  # Summary: Finds VLNV property value for the IP and checks to see if the IP is AXI_BFM
  # Argument Usage:
  # Return Value:
  # true (1) if specified IP is axi_bfm, false (0) otherwise

  foreach ip [get_ips -all -quiet] {
    set ip_def [lindex [split [get_property "IPDEF" [get_ips -all -quiet $ip]] {:}] 2]
    set ip_def_obj [get_ipdefs -quiet -regexp .*${ip_def}.*]
    #puts ip_def_obj=$ip_def_obj
    if { {} != $ip_def_obj } {
      set value [get_property "VLNV" $ip_def_obj]
      #puts is_axi_bfm_ip=$value
      if { ([regexp -nocase {axi_bfm} $value]) || ([regexp -nocase {processing_system7} $value]) } {
        return 1
      }
    }
  }
  return 0
}

proc xps_get_plat {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  set platform {}
  set os $::tcl_platform(platform)
  if { {windows} == $os } {
    set platform "win64"
    if { $a_sim_vars(b_32bit) } {
      set platform "win32"
    }
  }
  if { {unix} == $os } {
    set platform "lnx64"
    if { $a_sim_vars(b_32bit) } {
      set platform "lnx32"
    }
  }
  return $platform
}

proc xps_get_bfm_lib { simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set simulator_lib {}
  set xil           $::env(XILINX_VIVADO)
  set path_sep      {;}
  set lib_extn      {.dll}
  set platform      [xps_get_plat]

  if {$::tcl_platform(platform) == "unix"} { set path_sep {:} }
  if {$::tcl_platform(platform) == "unix"} { set lib_extn {.so} }

  set lib_name {}
  switch -regexp -- $simulator {
    "modelsim" -
    "questa"   { set lib_name "libxil_vsim" }
    "ies"      { set lib_name "libxil_ncsim" }
    "vcs"      { set lib_name "libxil_vcs" }
  }

  set lib_name $lib_name$lib_extn
  if { {} != $xil } {
    append platform ".o"
    set lib_path {}
    #send_msg_id exportsim-Tcl-116 INFO "Finding simulator library from 'XILINX_VIVADO'..."
    foreach path [split $xil $path_sep] {
      set file [file normalize [file join $path "lib" $platform $lib_name]]
      if { [file exists $file] } {
        #send_msg_id exportsim-Tcl-117 INFO "Using library:'$file'"
        set simulator_lib $file
        break
      } else {
        send_msg_id exportsim-Tcl-118 WARNING "Library not found:'$file'"
      }
    }
  } else {
    send_msg_id exportsim-Tcl-064 ERROR "Environment variable 'XILINX_VIVADO' is not set!"
  }
  return $simulator_lib
}

proc xps_get_incl_files_from_ip { launch_dir tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set incl_files [list]
  set ip_name [file tail $tcl_obj]
  set filter "FILE_TYPE == \"Verilog Header\""
  set vh_files [get_files -quiet -all -of_objects [get_files -quiet *$ip_name] -filter $filter]
  foreach file $vh_files {
    lappend incl_files $file
  }
  return $incl_files
}

proc xps_get_verilog_incl_file_dirs { simulator launch_dir { ref_dir "true" } } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  set dir_names [list]
  set vh_files [list]
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xps_is_ip $tcl_obj] } {
    set vh_files [xps_get_incl_files_from_ip $launch_dir $tcl_obj]
  } else {
    set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"Verilog Header\""
    set vh_files [get_files -all -quiet -filter $filter]
  }

  if { {} != $a_sim_vars(global_files_str) } {
    set global_files [split $a_sim_vars(global_files_str) {|}]
    foreach g_file $global_files {
      set g_file [string trim $g_file {\"}]
      lappend vh_files [get_files -quiet -all $g_file]
    }
  }
  foreach vh_file $vh_files {
    set vh_file_obj [lindex [get_files -all -quiet [list "$vh_file"]] 0]
    # set vh_file [extract_files -files [list "[file tail $vh_file]"] -base_dir $launch_dir/ip_files]
    set vh_file [xps_xtract_file $vh_file]
    if { [get_param project.enableCentralSimRepo] } {
      set bd_file {}
      set b_is_bd [xps_is_bd_file $vh_file bd_file]
      set used_in_values [get_property "USED_IN" $vh_file_obj]
      if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
        set vh_file [xps_fetch_header_from_dynamic $vh_file $b_is_bd]
      } else {
        if { $b_is_bd } {
          set vh_file [xps_fetch_ipi_static_file $vh_file]
        } else {
          set vh_file [xps_fetch_ip_static_file $vh_file $vh_file_obj]
        }
      }
    }
    set dir [file normalize [file dirname $vh_file]]

    if { $a_sim_vars(b_xport_src_files) } {
      set export_dir [file join $launch_dir "srcs/incl"]
      if {[catch {file copy -force $vh_file $export_dir} error_msg] } {
        send_msg_id exportsim-Tcl-065 WARNING "Failed to copy file '$vh_file' to '$export_dir' : $error_msg\n"
      }
    }

    if { $a_sim_vars(b_absolute_path) } {
      set dir "[xps_resolve_file_path $dir $launch_dir]"
    } else {
      if { $ref_dir } {
        if { $a_sim_vars(b_xport_src_files) } {
          set dir "\$ref_dir/incl"
          if { ({modelsim} == $simulator) || ({questa} == $simulator) } {
            set dir "srcs/incl"
          }
        } else {
          if { ({modelsim} == $simulator) || ({questa} == $simulator) } {
            set dir "[xps_get_relative_file_path $dir $launch_dir]"
          } else {
            set dir "\$ref_dir/[xps_get_relative_file_path $dir $launch_dir]"
          }
        }
      } else {
        if { $a_sim_vars(b_xport_src_files) } {
          set dir "srcs/incl"
        } else {
          set dir "[xps_get_relative_file_path $dir $launch_dir]"
        }
      }
    }
    lappend dir_names $dir
  }

  if {[llength $dir_names] > 0} {
    return [lsort -unique $dir_names]
  }
  return $dir_names
}

proc xps_get_verilog_incl_dirs { simulator launch_dir ref_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set dir_names [list]
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  set incl_dirs [list]
  set incl_dir_str {}

  if { [xps_is_ip $tcl_obj] } {
    set incl_dir_str [xps_get_incl_dirs_from_ip $simulator $launch_dir $tcl_obj]
    set incl_dirs [split $incl_dir_str "|"]
  } else {
    set incl_dir_str [xps_resolve_incldir [get_property "INCLUDE_DIRS" [get_filesets $tcl_obj]]]
    set incl_prop_dirs [split $incl_dir_str "|"]

    # include dirs from design source set
    set linked_src_set [get_property "SOURCE_SET" [get_filesets $tcl_obj]]
    if { {} != $linked_src_set } {
      set src_fs_obj [get_filesets $linked_src_set]
      set dirs [xps_resolve_incldir [get_property "INCLUDE_DIRS" [get_filesets $src_fs_obj]]]
      foreach dir [split $dirs "|"] {
        if { [lsearch -exact $incl_prop_dirs $dir] == -1 } {
          lappend incl_prop_dirs $dir
        }
      }
    }

    foreach dir $incl_prop_dirs {
      if { $a_sim_vars(b_absolute_path) } {
        set dir "[xps_resolve_file_path $dir $launch_dir]"
      } else {
        if { $ref_dir } {
          if { $a_sim_vars(b_xport_src_files) } {
            set dir "\$ref_dir/incl"
            if { ({modelsim} == $simulator) || ({questa} == $simulator) } {
              set dir "srcs/incl"
            }
          } else {
            if { ({modelsim} == $simulator) || ({questa} == $simulator) } {
              set dir "[xps_get_relative_file_path $dir $launch_dir]"
            } else {
              set dir "\$ref_dir/[xps_get_relative_file_path $dir $launch_dir]"
            }
          }
        } else {
          if { $a_sim_vars(b_xport_src_files) } {
            set dir "srcs/incl"
          } else {
            set dir "[xps_get_relative_file_path $dir $launch_dir]"
          }
        }
      }
      lappend incl_dirs $dir
    }
  }

  foreach vh_dir $incl_dirs {
    set vh_dir [string trim $vh_dir {\{\}}]
    lappend dir_names $vh_dir
  }
  return [lsort -unique $dir_names]
}

proc xps_resolve_incldir { incl_dirs } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set resolved_path {}
  set incl_dirs [string map {\\ /} $incl_dirs]
  set path_elem {}
  set comps [split $incl_dirs { }]
  foreach elem $comps {
    # path element starts slash (/)? or drive (c:/)?
    if { [string match "/*" $elem] || [regexp {^[a-zA-Z]:} $elem] } {
      if { {} != $path_elem } {
        # previous path is complete now, add hash and append to resolved path string
        set path_elem "$path_elem|"
        append resolved_path $path_elem
      }
      # setup new path
      set path_elem "$elem"
    } else {
      # sub-dir with space, append to current path
      set path_elem "$path_elem $elem"
    }
  }
  append resolved_path $path_elem
  return $resolved_path
}

proc xps_get_incl_dirs_from_ip { simulator launch_dir tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set ip_name [file tail $tcl_obj]
  set incl_dirs [list]
  set filter "FILE_TYPE == \"Verilog Header\""
  set vh_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_name] -filter $filter]
  foreach file $vh_files {
    # set file [extract_files -files [list "[file tail $file]"] -base_dir $launch_dir/ip_files]
    set file [xps_xtract_file $file]
    set dir [file dirname $file]
    if { [get_param project.enableCentralSimRepo] } {
      set b_static_ip_file 0
      set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
      set associated_library {}
      if { {} != $file_obj } {
        if { [lsearch -exact [list_property $file_obj] {LIBRARY}] != -1 } {
          set associated_library [get_property "LIBRARY" $file_obj]
        }
      }
      set file [xps_get_ip_file_from_repo $tcl_obj $file $associated_library $launch_dir b_static_ip_file]
      set dir [file dirname $file]
      # remove leading "./"
      if { [regexp {^\.\/} $dir] } {
        set dir [join [lrange [split $dir "/"] 1 end] "/"]
      }
      if { $a_sim_vars(b_xport_src_files) } {
        set dir "\$ref_dir/incl"
        if { ({modelsim} == $simulator) || ({questa} == $simulator) } {
          set dir "srcs/incl"
        }
      } else {
        if { ({modelsim} == $simulator) || ({questa} == $simulator) } {
          # not required, the dir is already returned in right format for relative and absolute
          #set dir "[xps_get_relative_file_path $dir $launch_dir]"
        } else {
          set dir "\$ref_dir/$dir"
        }
      }
    } else {
      if { $a_sim_vars(b_absolute_path) } {
        set dir "[xps_resolve_file_path $dir $launch_dir]"
      } else {
        if { $a_sim_vars(b_xport_src_files) } {
          set dir "\$ref_dir/incl"
        } else {
          set dir "\$ref_dir/[xps_get_relative_file_path $dir $launch_dir]"
        }
      }
    }
    lappend incl_dirs $dir
  }
  set incl_dirs [join $incl_dirs "|"]
  return $incl_dirs
}

proc xps_get_global_include_files { launch_dir incl_file_paths_arg incl_files_arg { ref_dir "true" } } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $incl_file_paths_arg incl_file_paths
  upvar $incl_files_arg      incl_files

  variable a_sim_vars
  set filesets       [list]
  set dir            $launch_dir
  set linked_src_set {}
  if { ([xps_is_fileset $a_sim_vars(sp_tcl_obj)]) && ({SimulationSrcs} == [get_property fileset_type $a_sim_vars(fs_obj)]) } {
    set linked_src_set [get_property "SOURCE_SET" $a_sim_vars(fs_obj)]
  }
  set incl_files_set [list]

  if { {} != $linked_src_set } {
    lappend filesets $linked_src_set
  }
  lappend filesets $a_sim_vars(fs_obj)
  set filter "FILE_TYPE == \"Verilog\" || FILE_TYPE == \"Verilog Header\" || FILE_TYPE == \"Verilog Template\""
  foreach fs_obj $filesets {
    set vh_files [get_files -quiet -all -of_objects [get_filesets $fs_obj] -filter $filter]
    foreach file $vh_files {
      # skip if not marked as global include
      if { ![get_property "IS_GLOBAL_INCLUDE" [lindex [get_files -quiet -all [list "$file"]] 0]] } {
        continue
      }
      # skip if marked user disabled
      if { [get_property "IS_USER_DISABLED" [lindex [get_files -quiet -all [list "$file"]] 0]] } {
        continue
      }
      set file [file normalize [string map {\\ /} $file]]
      if { [lsearch -exact $incl_files_set $file] == -1 } {
        lappend incl_files_set $file
        lappend incl_files     $file
        set incl_file_path [file normalize [string map {\\ /} [file dirname $file]]]
        if { $a_sim_vars(b_absolute_path) } {
          set incl_file_path "[xps_resolve_file_path $incl_file_path $launch_dir]"
        } else {
          if { $ref_dir } {
            if { $a_sim_vars(b_xport_src_files) } {
              set incl_file_path "\$ref_dir/incl"
            } else {
              set incl_file_path "\$ref_dir/[xps_get_relative_file_path $incl_file_path $dir]"
            }
          } else {
            if { $a_sim_vars(b_xport_src_files) } {
              set incl_file_path "srcs/incl"
            } else {
              set incl_file_path "[xps_get_relative_file_path $incl_file_path $dir]"
            }
          }
        }
        lappend incl_file_paths $incl_file_path
      }
    }
  }
}

proc xps_get_global_include_file_cmdstr { simulator launch_dir incl_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $incl_files_arg incl_files
  variable a_sim_vars
  set file_str [list]
  foreach file $incl_files {
    # set file [extract_files -files [list "[file tail $file]"] -base_dir $launch_dir/ip_files]
    lappend file_str "\"$file\""
  }
  return [join $file_str "|"]
}

proc xps_is_global_include_file { file_to_find } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  foreach g_file [split $a_sim_vars(global_files_str) {|}] {
    set g_file [string trim $g_file {\"}]
    if { [string compare $g_file $file_to_find] == 0 } {
      return true
    }
  }
  return false
}

proc xps_get_secureip_filelist {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  set data_dir [rdi::get_data_dir -quiet -datafile verilog/src/glbl.v]
  set file [file normalize [file join $data_dir "secureip/secureip_cell.list.f"]]
  set fh 0
  if {[catch {open $file r} fh]} {
    send_msg_id exportsim-Tcl-066 ERROR "failed to open file to read ($file))\n"
    return 1
  }
  set data [read $fh]
  close $fh
  set filelist [list]
  set data [split $data "\n"]
  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; } 
    set file_str [split [lindex [split $line {=}] 0] { }]
    set str_1 [string trim [lindex $file_str 0]]
    set str_2 [string trim [lindex $file_str 1]]
    #set str_2 [string map {\$XILINX_VIVADO $::env(XILINX_VIVADO)} $str_2]
    lappend filelist "$str_1 $str_2" 
  }
  return $filelist
}

proc xps_xtract_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  if { $a_sim_vars(b_extract_ip_sim_files) } {
    set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
    set xcix_ip_path [get_property core_container $file_obj]
    if { {} != $xcix_ip_path } {
      set ip_name [file root [file tail $xcix_ip_path]]
      set ip_ext_dir [get_property ip_extract_dir [get_ips -all -quiet $ip_name]]
      set ip_file "[xps_get_relative_file_path $file $ip_ext_dir]"
      # remove leading "../"
      set ip_file [join [lrange [split $ip_file "/"] 1 end] "/"]
      set file [file join $ip_ext_dir $ip_file]
    }
  }
  return $file
}

proc xps_is_static_ip_lib { library } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_ip_static_libs
  set library [string tolower $library]
  if { [lsearch $l_ip_static_libs $library] != -1 } {
    return true
  }
  return false
}

proc xps_write_filelist_info { dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  variable l_target_simulator
  set fh 0
  set file [file join $dir "file_info.txt"]
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-067 ERROR "failed to open file to write ($file)\n"
    return 1
  }
  set lines [list]
  lappend lines "Language File-Name IP Library File-Path"
  foreach file $a_sim_vars(l_design_files) {
    set fargs         [split $file {|}]
    set type          [lindex $fargs 0]
    set file_type     [lindex $fargs 1]
    set lib           [lindex $fargs 2]
    set proj_src_file [lindex $fargs 3]
    set ip_file       [lindex $fargs 5]
    set src_file      [lindex $fargs 6]
    set b_static_ip   [lindex $fargs 7]
    set filename [file tail $proj_src_file]
    set ipname   [file rootname [file tail $ip_file]]
  
    if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }
    set src_file [xps_resolve_file $proj_src_file $ip_file $src_file $dir]
    set pfile $src_file

    #set pfile "[xps_get_relative_file_path $proj_src_file $dir]"
    #if { $a_sim_vars(b_absolute_path) } {
    #  set pfile "[xps_resolve_file_path $proj_src_file $dir]"
    #}

    if { {} != $ipname } {
      lappend lines "$file_type, $filename, $ipname, $lib, $pfile"
    } else {
      lappend lines "$file_type, $filename, *, $lib, $pfile"
    }
  }
  if { [xps_contains_verilog] } {
    set file "glbl.v"
    if { $a_sim_vars(b_absolute_path) } {
      set file [file normalize [file join $dir $file]]
    }
    set top_lib [xps_get_top_library]
    lappend lines "Verilog, glbl.v, *, $top_lib, $file"
  }
  struct::matrix file_matrix;
  file_matrix add columns 5;
  foreach line $lines {
    file_matrix add row $line;
  }
  puts $fh [file_matrix format 2string]
  file_matrix destroy
  close $fh
  return 0
}

proc xps_resolve_file { proj_src_file ip_file src_file dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set src_file [string trim $src_file "\""]
  if { {} == $ip_file } {
    set source_file [string trim $proj_src_file {\"}]
    if { $a_sim_vars(b_absolute_path) } {
      set src_file "[xps_resolve_file_path $source_file $dir]"
    } else {
      set src_file "[xps_get_relative_file_path $source_file $dir]"
    }
  }
  if { $a_sim_vars(b_xport_src_files) } {
    if { {} != $ip_file } {
      set proj_src_filename [file tail $proj_src_file]
      set ip_name [file rootname [file tail $ip_file]]
      set proj_src_filename "ip/$ip_name/$proj_src_filename"
      set src_file "srcs/$proj_src_filename"
    } else {
      set src_file "srcs/[file tail $proj_src_file]"
    }
    if { $a_sim_vars(b_absolute_path) } {
      set src_file [file normalize [file join $dir $src_file]]
    }
  }
  return $src_file
}

proc xps_find_comp { comps_arg index_arg to_match } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $comps_arg comps
  upvar $index_arg index
  set index 0
  set b_found false
  foreach comp $comps {
    incr index
    if { $to_match != $comp } continue;
    set b_found true
    break
  }
  return $b_found
}
}
