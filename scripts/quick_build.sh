DATE_PREFIX=$(date +%Y-%m-%d)
TIMESTAMP=$(date -u +%s)

filename_base="document_${DATE_PREFIX}"

suffix=''
flags=''
pre_tex='\def\TAGPDF{}'

flavours_u=("2u")
flavours_A=("3a" "ua1")
flavours_UA=("4f" "ua2" "wt1r" "wt1a")

flavours=$flavours_UA


success=true  # flag for success of the workflow

main_tex_file=${1:-main}
output_dir='./output'
build_dir='./build'

mkdir -p $build_dir
mkdir -p $output_dir

filename_flat="${filename_base}${suffix}"
filename="${filename_flat}"
counter=1
while [ -f "${output_dir}/${filename}.pdf" ]; do
    filename="${filename_flat}_${counter}"
    ((counter++))
done

# Build pdf
podman run --rm -it \
    -e SOURCE_DATE_EPOCH=${TIMESTAMP} \
    -e FORCE_SOURCE_DATE=1 \
    -v "$(pwd)":/data:Z \
    -v $output_dir:/output:Z \
    -v $build_dir:/build:Z \
    -w /data \
    texlive/texlive \
    latexmk ${flags[$i]:+${flags[$i]}} -g -usepretex="${pre_tex[$i]}" "${main_tex_file}.tex" -jobname="${filename}"

build_exit_code=$?
if [ $build_exit_code -ne 0 ]; then
    echo "Failure building ${filename}"
    success=false
fi

# Validate
for flav in ${flavours[@]}; do
    output=$(podman run --rm -it \
        -v $output_dir:/data:Z \
        verapdf/cli \
        --flavour ${flav} --format text "${filename}.pdf")

    if [[ "$output" == PASS* ]]; then
        :
    elif [[ "$output" == FAIL* ]]; then
        echo "Validation failed for ${filename} with flavour ${flav}"
        success=false
    else
        echo "Error validating ${filename} with flavour ${flav}"
        success=false
    fi
done

# Overall success of the operations
if $success; then
    echo "Everything successful"
fi



# for main_file in main*.tex; do
#     if [[ -f "$file" ]]; then
#         # Extract suffix between 'main' and '.tex'
#         suffix="${main_file#main}"
#         suffix="${suffix%.tex}"
#         latexmk ${{ inputs.flags }} -g -usepretex="${{ inputs.pre_tex }}" $main_file -jobname="${{ env.dirname }}${{ inputs.filename }}${suffix}"
#     fi
# done
