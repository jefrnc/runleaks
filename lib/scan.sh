#!/bin/bash

repo="$2"
run_count=$3
min_days_old=$6
max_days_old=$7
max_proc_count=8
log_file=exceptions_search.txt

echo "$1" >auth.txt
gh auth login --with-token <auth.txt

cp "$4" /patterns.txt
cp "$5" /.gitallowed

# Register patterns
grep -v -E '(#.*$)|(^$)' /patterns.txt >/clean_patterns.txt
while read line; do
  if [[ "$line" != "#*" ]]; then
    git secrets $line --global
  fi
done </clean_patterns.txt

echo "Repo: $2"
echo "Run limit: $3"
echo "============================================================================================"
echo "Scan patterns:"
echo "============================================================================================"
git secrets --list --global
echo "============================================================================================"
echo "Excluded patterns:"
echo "============================================================================================"
cat /.gitallowed
echo "============================================================================================"

# Collect up to 500/day id runs
run_list_limit=$((($max_days_old - $min_days_old) * 500))

# Collect ids of workflow runs
declare -a run_ids=$(gh run list --repo "CDCgov/prime-reportstream" --json databaseId,status,updatedAt --jq '.[] | select(.updatedAt <= ((now - ('"$min_days_old"'*86400))|strftime("%Y-%m-%dT%H:%M:%S %Z"))) | select(.updatedAt > ((now - ('"$max_days_old"'*86400))|strftime("%Y-%m-%dT%H:%M:%S %Z"))) | select(.status =="completed").databaseId' --limit $run_list_limit)
run_ids_limited=$(printf "%s\n" ${run_ids[@]} | head -$run_count)

echo "Runs limited:"
echo $run_ids_limited

touch "$log_file"
run_for_each() {
  local each=$@

  # Collect run logs and remove null
  log_out=$(gh run view $each --repo "$repo" --log 2>/dev/null | sed 's/\x0//g')

  # Identify potential exceptions
  echo "$log_out" | git secrets --scan - 2>/dev/null
  status=$?
  if (($status != 0)); then
    # Collect run details if run exception found
    exception=$(gh run view $each --repo "$repo" --json name,createdAt,databaseId,url,updatedAt,headBranch 2>/dev/null)
    echo $exception >>"$log_file"
  fi
}

# Make visible to subprocesses
export -f run_for_each
export log_file
export repo

parallel -0 --jobs $max_proc_count run_for_each ::: $run_ids_limited

json_out=$(jq -n '.exceptions |= [inputs]' "$log_file")

# Make output friendly
json_out="${json_out//'%'/'%25'}"
json_out="${json_out//$'\n'/'%0A'}"
json_out="${json_out//$'\r'/'%0D'}"
echo "::set-output name=exceptions::$json_out"

rm "$log_file"
