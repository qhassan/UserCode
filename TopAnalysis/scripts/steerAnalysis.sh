#!/bin/bash

WHAT=$1; if [[ "$1" == "" ]]; then echo "steerAnalysis.sh <SEL/MERGE/PLOT/BKG>"; exit 1; fi

queue=8nh
eosdir=/store/cmst3/user/psilva/LJets2015/64217e8
outdir=~/work/LJets2015/
wwwdir=~/www/LJets2015
lumi=2134

RED='\e[31m'
NC='\e[0m'

case $WHAT in
    SEL )
	echo -e "[ ${RED} Submitting the selection for the signal regions ${NC} ]"
	python scripts/runLocalAnalysis.py -i ${eosdir} -q ${queue} --runSysts -o ${outdir}/analysis_muplus   --ch 13   --charge 1
	python scripts/runLocalAnalysis.py -i ${eosdir} -q ${queue} --runSysts -o ${outdir}/analysis_muminus  --ch 13   --charge -1
	python scripts/runLocalAnalysis.py -i ${eosdir} -q ${queue} --runSysts -o ${outdir}/analysis_eplus   --ch 11   --charge 1
	python scripts/runLocalAnalysis.py -i ${eosdir} -q ${queue} --runSysts -o ${outdir}/analysis_eminus  --ch 11   --charge -1
	
	echo -e "[ ${RED} Submitting the selection for the control regions ${NC} ]"
	python scripts/runLocalAnalysis.py -i ${eosdir} -q ${queue}            -o ${outdir}/analysis_munoniso --ch 1300
	python scripts/runLocalAnalysis.py -i ${eosdir} -q ${queue}            -o ${outdir}/analysis_enoniso --ch 1100
	python scripts/runLocalAnalysis.py -i ${eosdir} -q ${queue} --runSysts -o ${outdir}/analysis_z --ch 21
	;;
    MERGE )
	a=(muplus muminus eplus eminus munoniso enoniso z)
	for i in ${a[@]}; do
	    echo -e "[ ${RED} Merging ${i} ${NC} ]"
	    ./scripts/mergeOutputs.py ${outdir}/analysis_${i};
	done
	;;
    PLOT )
	a=(muplus muminus eplus eminus munoniso enoniso z)
	for i in ${a[@]}; do
	    echo -e "[ ${RED} Creating plotter for ${i} ${NC} ]"
	    python scripts/plotter.py -i ${outdir}/analysis_${i}/ --puNormSF puwgtctr  -j data/samples_Run2015.json -l ${lumi} --saveLog
	done

	a=(muplus muminus eplus eminus)
	for i in ${a[@]}; do
	    echo -e "[ ${RED} Creating plotter for ${i} ${NC} ]"	
	    python scripts/plotter.py -i ${outdir}/analysis_${i}/ --puNormSF puwgtctr  -j data/syst_samples_Run2015.json -l ${lumi} -o syst_plotter.root --silent
	done
	;;
    BKG )
	a=(mu e)
	b=(plus minus)
	for i in ${a[@]}; do
	    for j in ${b[@]}; do
		python scripts/runQCDEstimation.py --iso ${outdir}/analysis_${i}${j}/plots/plotter.root --noniso ${outdir}/analysis_${i}noniso/plots/plotter.root --out ${outdir}/analysis_${i}${j}/
	    done
	done
	;;
    WWW )
	a=(muplus muminus eplus eminus munoniso enoniso z)
	for i in ${a[@]}; do
	    echo -e "[ ${RED} Moving plots for ${i} ${NC} ]"
	    mkdir -p ${wwwdir}/${i};
	    cp ${outdir}/analysis_${i}/plots/*.{png,pdf} ${wwwdir}/${i};
	    cp test/index.php ${wwwdir}/${i};
	done
	;;
    CinC )
	echo -e "[ ${RED} Creating datacards ${NC} ]"
	a=(mu e)
	b=(plus minus)
	finalDataCards=""
	minusDataCards=""
	plusDataCards=""
	for i in ${a[@]}; do

	    chDataCards=""
	    for j in ${b[@]}; do
		python scripts/createDataCard.py -i ${outdir}/analysis_${i}${j}/plots/plotter.root --systInput ${outdir}/analysis_${i}${j}/plots/syst_plotter.root -q ${outdir}/analysis_${i}${j}/.qcdscalefactors.pck -d nbtags -o ${outdir}/analysis_${i}${j}/datacard;
		cd ${outdir}/analysis_${i}${j}/datacard;
		combineCards.py ${i}${j}1j=datacard_1j.dat ${i}${j}2j=datacard_2j.dat ${i}${j}3j=datacard_3j.dat ${i}${j}4j=datacard_4j.dat > datacard.dat
		chDataCards="${i}${j}=../../analysis_${i}${j}/datacard/datacard.dat ${chDataCards}"
		if [ "${j}" = "plus" ]; then
		    plusDataCards="${i}${j}=../../analysis_${i}${j}/datacard/datacard.dat ${plusDataCards}"
		else
		    minusDataCards="${i}${j}=../../analysis_${i}${j}/datacard/datacard.dat ${minusDataCards}"
		fi
		cd -
	    done

	    #channel conbination
	    echo "Combining datacards for ch=${i} from ${chDataCards}"
	    mkdir -p ${outdir}/analysis_${i}/datacard
	    cd ${outdir}/analysis_${i}/datacard
	    combineCards.py ${chDataCards} > datacard.dat
	    finalDataCards="${chDataCards} ${finalDataCards}"
	    cd -
	done
	
	echo "Combining datacards for all channels from ${finalDataCards}"
	mkdir -p ${outdir}/analysis/datacard/
	cd ${outdir}/analysis/datacard/
	combineCards.py ${finalDataCards} > datacard.dat
	cd -

	echo "Combining datacards for all + channels from ${plusDataCards}"
	mkdir -p ${outdir}/analysis_plus/datacard/
	cd ${outdir}/analysis_plus/datacard/
	combineCards.py ${finalDataCards} > datacard.dat
	cd -

	echo "Combining datacards for all - channels from ${minusDataCards}"
	mkdir -p ${outdir}/analysis_minus/datacard/
	cd ${outdir}/analysis_minus/datacard/
	combineCards.py ${finalDataCards} > datacard.dat
	cd -

	a=("mu" "e")
	b=("plus" "minus")
	for i in ${a[@]}; do
	    for j in ${b[@]}; do 
		title="#mu"		
		if [ "${i}${j}" = "muplus" ]; then
		    title="#mu^{+}";
		elif [ "${i}${j}" = "muminus" ]; then
		    title="#mu^{-}";
		elif [ "${i}${j}" = "eplus" ]; then
		    title="e^{+}";
		elif [ "${i}${j}" = "eminus" ]; then
		    title="e^{-}";
		fi
		echo -e "[ ${RED} Running the fit for ${title} ${NC} ]"
		python scripts/fitCrossSection.py "${title}"=${outdir}/analysis_${i}${j}/datacard/datacard.dat -o ${outdir}/analysis_${i}${j}/datacard; 
	    done
	    
	    #combined per channel
	    title="#mu"
	    if [ "${i}" = "e" ]; then
		    title="e"
	    fi
	    echo -e "[ ${RED} Running the fit for ${title} ${NC} ]"
            python scripts/fitCrossSection.py "${title}"=${outdir}/analysis_${i}/datacard/datacard.dat -o ${outdir}/analysis_${i}/datacard;

	done

	#combined per charge
	for j in ${b[@]}; do 
	    title="e^{+}/#mu^{+}"
	    if [ "${j}" = "minus" ]; then
                title="e^{-}/#mu^{-}";
            fi
	    echo -e "[ ${RED} Running the fit for ${title} ${NC} ]"
            python scripts/fitCrossSection.py "${title}"=${outdir}/analysis_${j}/datacard/datacard.dat -o ${outdir}/analysis_${j}/datacard;
	done

	#final combination
	echo -e "[ ${RED} Running the final ${NC} ]"
        python scripts/fitCrossSection.py "e/#mu"=${outdir}/analysis/datacard/datacard.dat -o ${outdir}/analysis/datacard;

	;;
    SHAPE )
	echo -e "[ ${RED} Creating shape datacards ${NC} ]"
	a=(mu e)
	b=(plus minus)
	finalDataCards=""
	minusDataCards=""
	plusDataCards=""
	for i in ${a[@]}; do

	    chDataCards=""
	    for j in ${b[@]}; do

		
		python scripts/createDataCard.py -i ${outdir}/analysis_${i}${j}/plots/plotter.root --systInput ${outdir}/analysis_${i}${j}/plots/syst_plotter.root -o  ${outdir}/analysis_${i}${j}/datacard_shape  -q ${outdir}/analysis_${i}${j}/.qcdscalefactors.pck -d mt     -c 1j0t,2j0t,3j0t,4j0t;
		python scripts/createDataCard.py -i ${outdir}/analysis_${i}${j}/plots/plotter.root --systInput ${outdir}/analysis_${i}${j}/plots/syst_plotter.root -o  ${outdir}/analysis_${i}${j}/datacard_shape  -q ${outdir}/analysis_${i}${j}/.qcdscalefactors.pck -d minmlb -c 1j1t,2j1t,2j2t,3j1t,3j2t,4j1t,4j2t;

		cd ${outdir}/analysis_${i}${j}/datacard_shape;
		combineCards.py ${i}${j}1j0t=datacard_1j0t.dat \
		    ${i}${j}1j1t=datacard_1j1t.dat \
		    ${i}${j}2j0t=datacard_2j0t.dat \
		    ${i}${j}2j1t=datacard_2j1t.dat \
		    ${i}${j}2j2t=datacard_2j2t.dat \
		    ${i}${j}3j0t=datacard_3j0t.dat \
		    ${i}${j}3j1t=datacard_3j1t.dat \
		    ${i}${j}3j2t=datacard_3j2t.dat \
		    ${i}${j}4j0t=datacard_4j0t.dat \
		    ${i}${j}4j1t=datacard_4j1t.dat \
		    ${i}${j}4j2t=datacard_4j2t.dat > datacard.dat
		chDataCards="${i}${j}=../../analysis_${i}${j}/datacard_shape/datacard.dat ${chDataCards}"
		if [ "${j}" = "plus" ]; then
		    plusDataCards="${i}${j}=../../analysis_${i}${j}/datacard_shape/datacard.dat ${plusDataCards}"
		else
		    minusDataCards="${i}${j}=../../analysis_${i}${j}/datacard_shape/datacard.dat ${minusDataCards}"
		fi
		cd -
	    done

	    #channel conbination
	    echo "Combining datacards for ch=${i} from ${chDataCards}"
	    mkdir -p ${outdir}/analysis_${i}/datacard_shape
	    cd ${outdir}/analysis_${i}/datacard_shape
	    combineCards.py ${chDataCards} > datacard.dat
	    finalDataCards="${chDataCards} ${finalDataCards}"
	    cd -
	done
	
	echo "Combining datacards for all channels from ${finalDataCards}"
	mkdir -p ${outdir}/analysis/datacard_shape/
	cd ${outdir}/analysis/datacard_shape/
	combineCards.py ${finalDataCards} > datacard.dat
	cd -

	echo "Combining datacards for all + channels from ${plusDataCards}"
	mkdir -p ${outdir}/analysis_plus/datacard_shape/
	cd ${outdir}/analysis_plus/datacard_shape/
	combineCards.py ${finalDataCards} > datacard.dat
	cd -

	echo "Combining datacards for all - channels from ${minusDataCards}"
	mkdir -p ${outdir}/analysis_minus/datacard_shape/
	cd ${outdir}/analysis_minus/datacard_shape/
	combineCards.py ${finalDataCards} > datacard.dat
	cd -

	a=("mu" "e")
	b=("plus" "minus")
	for i in ${a[@]}; do
	    for j in ${b[@]}; do 
		title="#mu"		
		if [ "${i}${j}" = "muplus" ]; then
		    title="#mu^{+}";
		elif [ "${i}${j}" = "muminus" ]; then
		    title="#mu^{-}";
		elif [ "${i}${j}" = "eplus" ]; then
		    title="e^{+}";
		elif [ "${i}${j}" = "eminus" ]; then
		    title="e^{-}";
		fi
		echo -e "[ ${RED} Running the fit for ${title} ${NC} ]"
		python scripts/fitCrossSection.py "${title}"=${outdir}/analysis_${i}${j}/datacard_shape/datacard.dat -o ${outdir}/analysis_${i}${j}/datacard_shape; 
	    done
	    
	    #combined per channel
	    title="#mu"
	    if [ "${i}" = "e" ]; then
		    title="e"
	    fi
	    echo -e "[ ${RED} Running the fit for ${title} ${NC} ]"
            python scripts/fitCrossSection.py "${title}"=${outdir}/analysis_${i}/datacard_shape/datacard.dat -o ${outdir}/analysis_${i}/datacard_shape;

	done

	#combined per charge
	for j in ${b[@]}; do 
	    title="e^{+}/#mu^{+}"
	    if [ "${j}" = "minus" ]; then
                title="e^{-}/#mu^{-}";
            fi
	    echo -e "[ ${RED} Running the fit for ${title} ${NC} ]"
            python scripts/fitCrossSection.py "${title}"=${outdir}/analysis_${j}/datacard_shape/datacard.dat -o ${outdir}/analysis_${j}/datacard_shape;
	done

	#final cobmination
	echo -e "[ ${RED} Running the final ${NC} ]"
        python scripts/fitCrossSection.py "e/#mu"=${outdir}/analysis/datacard_shape/datacard.dat -o ${outdir}/analysis/datacard_shape;

	;;
    



esac