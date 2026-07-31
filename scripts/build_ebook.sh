DATE_PREFIX=$(date +%Y-%m-%d)

filename_base="coffins_ebook_${DATE_PREFIX}"

output_dir='../output'
build_dir_mathml='../build_ml'
build_dir_svg='../build_svg'

mkdir -p $build_dir_svg
mkdir -p $build_dir_mathml
mkdir -p $output_dir

success=true  # flag for success of the workflow

filename="${filename_base}"
counter=1
while [ -f "${output_dir}/${filename}_svg.epub" ] || [ -f "${output_dir}/${filename}_mathml.epub" ]; do
    filename="${filename_base}_${counter}"
    ((counter++))
done


podman run --rm \
  -v "$(pwd)":/data:Z \
  -v "${output_dir}":/output:Z \
  -v "${build_dir_svg}":/build:Z \
  -w /data \
  texlive/texlive \
  tex4ebook --build-dir "${build_dir_svg}" --output-dir "${output_dir}" --format epub --jobname "${filename}_svg" main.tex svg "" "" "\\\\def\\\\NOSOLUTIONS{} \\\\def\\\\NOSOURCES{}"

build_exit_code=$?
if [ $build_exit_code -ne 0 ]; then
    echo "Failure building ${filename} as SVG"
    success=false
fi


podman run --rm \
  -v "$(pwd)":/data:Z \
  -v "${output_dir}":/output:Z \
  -v "${build_dir_mathml}":/build:Z \
  -w /data \
  texlive/texlive \
  tex4ebook --build-dir "${build_dir_mathml}" --output-dir "${output_dir}" --format epub3 --jobname "${filename}_ml" main.tex mathml "" "" "\\\\def\\\\NOSOLUTIONS{} \\\\def\\\\NOSOURCES{}"

build_exit_code=$?
if [ $build_exit_code -ne 0 ]; then
    echo "Failure building ${filename} as MathML"
    success=false
fi
