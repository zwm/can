#/bin/bash
ps -ef --sort=start_time| grep 'lmgrd' | awk '{print $2}' | sed -n '1p' | xargs kill || true
echo "Next Command ..."
/tools/synopsys/scl/scl_11.9/amd64/bin/lmgrd -c /tools/synopsys/license/synopsys.dat -l /tmp/synopsys_lmgrd.log
