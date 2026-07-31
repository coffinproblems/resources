DATE_PREFIX=$(date +%Y-%m-%d)
TIMESTAMP=$(date -u +%s)

filename_base="coffins_${DATE_PREFIX}"

options=("_u" "_UA" "_A" "_p")
flags=("" "" "" "-pdflatex")
pre_tex=("\def\ALL{} \def\MOREREFS{} \def\FORUMREFS{}" \
         "\def\ALL{} \def\MOREREFS{} \def\FORUMREFS{} \def\TAGPDF{}" \
         "\def\ALL{} \def\MOREREFS{} \def\FORUMREFS{} \def\PDFAA{}" \
         "\def\ALL{} \def\MOREREFS{} \def\FORUMREFS{}")

flavours_u=("2u")
flavours_A=("3a" "ua1")
flavours_UA=("4f" "ua2" "wt1r" "wt1a")

flavours=(flavours_u flavours_UA flavours_A flavours_u)


success=true  # flag for success of the workflow

mkdir -p ../build
mkdir -p ../output

n=${#options[@]}
for ((i=0; i<n; i++)); do
    filename_flat="${filename_base}${options[$i]}"
    filename="${filename_flat}"
    counter=1
    while [ -f "../output/${filename}.pdf" ]; do
        filename="${filename_flat}_${counter}"
        ((counter++))
    done

    # Build pdf
    podman run --rm -it \
        -e SOURCE_DATE_EPOCH=${TIMESTAMP} \
        -e FORCE_SOURCE_DATE=1 \
        -v "$(pwd)":/data:Z \
        -v "$(pwd)"/../output:/output:Z \
        -v "$(pwd)"/../build:/build:Z \
        -w /data \
        texlive/texlive \
        latexmk ${flags[$i]:+${flags[$i]}} -g -usepretex="${pre_tex[$i]}" main.tex -jobname="${filename}"

    build_exit_code=$?
    if [ $build_exit_code -ne 0 ]; then
        echo "Failure building ${filename}"
        success=false
        continue
    fi

    rm -r ../build
    mkdir ../build

    # Validate
    declare -n current_flavours="${flavours[$i]}"
    for flav in "${current_flavours[@]}"; do
        output=$(podman run --rm -it \
            -v "$(pwd)"/../output:/data:Z \
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

    # Build again
    mv "../output/${filename}.pdf" "../output/${filename}_PREV.pdf"  # rename the old one because the new one needs to be built with same name for reproducibility
    podman run --rm -it \
        -e SOURCE_DATE_EPOCH=${TIMESTAMP} \
        -e FORCE_SOURCE_DATE=1 \
        -v "$(pwd)":/data:Z \
        -v "$(pwd)"/../output:/output:Z \
        -v "$(pwd)"/../build:/build:Z \
        -w /data \
        texlive/texlive \
        latexmk ${flags[$i]:+${flags[$i]}} -g -usepretex="${pre_tex[$i]}" main.tex -jobname="${filename}"

    rebuild_exit_code=$?
    if [ $rebuild_exit_code -ne 0 ]; then
        echo "Failure rebuilding ${filename}"
        success=false
        continue
    fi

    # Compare to previous build
    cmp -s "../output/${filename}.pdf" "../output/${filename}_PREV.pdf"
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
        rm "../output/${filename}_PREV.pdf"  # Remove the extra file
    elif [ $exit_code -eq 1 ]; then
        echo "Failed to reproduce ${filename}"
        success=false
    else
        echo "Error comparing ${filename}"
        success=false
    fi

done

# Overall success of the operations
if $success; then
    echo "Everything successful"
fi




# Problems and solutions

#       - name: PDF - problems and solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: latexmk main.tex
#
#       - name: Minimal PDF - problems and solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: latexmk -g -usepretex="\def\MINIMAL{}" main.tex
#
#       - name: EPUB - problems and solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: tex4ebook -B ../build_epub3 -d ../output -f epub3 main.tex mathml
#
#       - name: TeX source - problems and solutions
#         run: python ../scripts/flatten.py main.tex
#
#
#       # Problems, without solutions
#
#       - name: PDF - problems, without solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: latexmk -g -usepretex="\def\NOSOLUTIONS{}" main.tex
#
#       - name: Minimal PDF - problems, without solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: latexmk -g -usepretex="\def\NOSOLUTIONS{} \def\MINIMAL{}" main.tex
#
#       - name: EPUB - problems, without solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: tex4ebook -B ../build_epub3 -d ../output -f epub3 main.tex mathml "" "" '\\def\\NOSOLUTIONS{}'
#
#       - name: TeX source - problems, without solutions
#         run: python ../scripts/flatten.py main.tex NOSOLUTIONS
#
#
#       # Only solutions
#
#       - name: PDF - only solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: latexmk -g -usepretex="\def\ONLYSOLUTIONS{}" main.tex
#
#       - name: Minimal PDF - only solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: latexmk -g -usepretex="\def\ONLYSOLUTIONS{} \def\MINIMAL{}" main.tex
#
#       - name: EPUB - only solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: tex4ebook -B ../build_epub3 -d ../output -f epub3 main.tex mathml "" "" '\\def\\ONLYSOLUTIONS{}'
#
#       - name: TeX source - only solutions
#         run: python ../scripts/flatten.py main.tex ONLYSOLUTIONS
#
#
#
#
#       # Generalised problems and solutions
#
#       - name: PDF - generalised problems and solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: latexmk -g -usepretex="\def\GENERALISED{}" main.tex
#
#       - name: Minimal PDF - generalised problems and solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: latexmk -g -usepretex="\def\GENERALISED{} \def\MINIMAL{}" main.tex
#
#       - name: EPUB - generalised problems and solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: tex4ebook -B ../build_epub3 -d ../output -f epub3 main.tex mathml "" "" '\\def\\GENERALISED{}'
#
#       - name: TeX source - generalised problems and solutions
#         run: python ../scripts/flatten.py main.tex GENERALISED
#
#
#       # Generalised problems, without solutions
#
#       - name: PDF - generalised problems, without solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: latexmk -g -usepretex="\def\GENERALISED{} \def\NOSOLUTIONS{}" main.tex
#
#       - name: Minimal PDF - generalised problems, without solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: latexmk -g -usepretex="\def\GENERALISED{} \def\NOSOLUTIONS{} \def\MINIMAL{}" main.tex
#
#       - name: EPUB - generalised problems, without solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: tex4ebook -B ../build_epub3 -d ../output -f epub3 main.tex mathml "" "" '\\def\\GENERALISED{} \\def\\NOSOLUTIONS{}'
#
#       - name: TeX source - generalised problems, without solutions
#         run: python ../scripts/flatten.py main.tex GENERALISED NOSOLUTIONS
#
#
#       # Only solutions to the generalised problems
#
#       - name: PDF - generalised, only solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: latexmk -g -usepretex="\def\GENERALISED{} \def\ONLYSOLUTIONS{}" main.tex
#
#       - name: Minimal PDF - generalised, only solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: latexmk -g -usepretex="\def\GENERALISED{} \def\ONLYSOLUTIONS{} \def\MINIMAL{}" main.tex
#
#       - name: EPUB - generalised, only solutions
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: tex4ebook -B ../build_epub3 -d ../output -f epub3 main.tex mathml "" "" '\\def\\GENERALISED{} \\def\\ONLYSOLUTIONS{}'
#
#       - name: TeX source - generalised, only solutions
#         run: python ../scripts/flatten.py main.tex GENERALISED ONLYSOLUTIONS
#
#
#
#       # Variants to test different compilation options and TeX engines
#
#       - name: PDF - full, pdflatex, PDF/A-2u
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: latexmk -g -usepretex="\def\ALL{} \def\MOREREFS{} \def\FORUMREFS{}" main.tex
#
#       - name: PDF - full, PDF/A-3a
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: latexmk -g -usepretex="\def\ALL{} \def\MOREREFS{} \def\FORUMREFS{} \def\PDFAA{}" main.tex
#
#       - name: PDF - full, PDF/A-4f, PDF/UA-2
#         env:
#           SOURCE_DATE_EPOCH: ${{ env.TIMESTAMP }}
#         run: latexmk -g -usepretex="\def\ALL{} \def\MOREREFS{} \def\FORUMREFS{} \def\TAGPDF{}" main.tex
