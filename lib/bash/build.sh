# lib/bash/build.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function number_of_processors()
{
	local result=
	case $METASYSTEM_OS in
		linux)
			result=$NUMBER_OF_PROCESSORS
			[[ -z $result && -e /proc/cpuinfo ]] &&\
				result=`cat /proc/cpuinfo | grep ^processor | wc -l`
			;;
		mac)
			result=`sysctl hw.ncpu | cut -d" " -f2`
			;;
	esac
	echo $result
}

# Enhanced 'make' function
# Defines the following additional switches:
#     -parallel: use all available CPUs; prioritise make jobs on Linux scheduler
#     -log: tee output to timestamped file in $MAKE_LOG_DIR, if that is defined
#     -time: measure time
function make()
{
	local cmd=$(which make)
	local args=
	local parallel=$METASYSTEM_MAKE_PARALLEL
	local sched=$METASYSTEM_MAKE_SCHED
	local log=$METASYSTEM_MAKE_LOG
	local measure_time=$METASYSTEM_MEASURE_TIME
	local vanilla=$METASYSTEM_MAKE_VANILLA

	for x in "$@"; do
		case $x in
			-log | --log | -log=yes | --log=yes)
				log=1
				;;
			-no-log | --no-log | -log=no | --log=no)
				log=
				;;
			-parallel | --parallel | -parallel=yes | --parallel=yes)
				parallel=1
				;;
			-no-parallel | --no-parallel | -parallel=no | --parallel=no)
				parallel=
				;;
			-sched | --sched | -sched=yes | --sched=yes)
				sched=1
				;;
			-no-sched | --no-sched | -sched=no | --sched=no)
				sched=
				;;
			-time | --time | -time=yes | --time=yes)
				measure_time=1
				;;
			-no-time | --no-time | -time=no | --time=no)
				measure_time=
				;;

			# Redirection breaks ncurses
			menuconfig)
				vanilla=1
				args="$args $x"
				;;

			*)
				args="$args $x"
				;;
		esac
	done
	cmd="$cmd$args"

	if [[ $vanilla == 1 ]]; then
		$cmd
	else
		local rc=0
		if [[ $parallel == 1 ]]; then
			local ncpus=$(number_of_processors)
			if [[ -n $ncpus ]]; then
				local njobs=$ncpus
				cmd="$cmd -j $njobs"
			else
				echo "Warning: number_of_processors returned an empty string" >&2
			fi
		fi
		[[ $sched == 1 && $METASYSTEM_OS == linux ]] &&\
			cmd="schedtool -B -n 1 -e ionice -n 1 $cmd"

		output="Directory ................... $(pwd)\n"
		output="${output}Start time .................. $(date)\n"
		output="${output}Parallel .................... $parallel\n"
		output="${output}Schedule boost .............. $sched\n"
		if [[ -n $parallel ]]; then
			output="${output}Number of processors ........ $ncpus\n"
			output="${output}Number of jobs .............. $njobs\n"
		fi
		output="${output}Measure time ................ $measure_time\n"
		output="${output}Command ..................... $cmd"

		local log_file=
		if [[ $log == 1 ]]; then
			if [[ -z $MAKE_LOG_DIR ]]; then
				echo "Warning: MAKE_LOG_DIR is not defined, so ignoring --log" >&2
			else
				log_file=$(log_file MAKE_LOG_DIR make)
			fi
		fi

		if [[ -n $log_file ]]; then
			echo -e "Log file .................... $log_file\n" >&2
			touch $log_file
			echo -e $output | tee -a $log_file
			echo | tee -a $log_file
			(time $cmd) 2>&1 | tee -a $log_file
			# Use PIPESTATUS rather than $? to capture exit code from make
			# rather than tee
			rc=${PIPESTATUS[0]}
			echo | tee -a $log_file
			echo "End time .................... $(date)" | tee -a $log_file
			echo "Log file .................... $log_file" >&2
		else
			[[ -z $METASYSTEM_MAKE_SILENT ]] && echo -e "$output\n" >&2
			if [[ $measure_time == 1 ]]; then
				time $cmd
				rc=$?
			else
				$cmd
				rc=$?
			fi
		fi
		[[ $rc != 0 ]] && echo "Failed with exit code $rc" >&2
		return $rc
	fi
}

