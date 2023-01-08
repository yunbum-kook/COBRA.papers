% The predictive capacity of each model generated by driver_createMultipleIDNModels
% is evaluated using the modelPredictiveCapacity function to ifentify the
% model with the predictive capacity. Save the results as accuracy.mat on each directory
%
% The results are saved in:
% ~/work/sbgCloud/programReconstruction/projects/exoMetDN/results/codeResults/iDN1

clear

%param.approach ='SD';
%param.approach ='mean';
param.approach='UptSec';

recompute = 1;

% Select solver
if contains(char(java.lang.System.getProperty('user.name')),'rfleming')
    [~, ~] = changeCobraSolver('mosek', 'EP', 0);
    [~, ~] = changeCobraSolver('ibm_cplex', 'QP', 0);
    [~, ~] = changeCobraSolver('ibm_cplex', 'LP', 0);
else
    [~, ~] = changeCobraSolver('gurobi', 'all', 0);
end
    
% Define results directory
if contains(char(java.lang.System.getProperty('user.name')),'rfleming')
    modelsDir = ['~' filesep 'work' filesep 'sbgCloud' filesep 'programReconstruction' ...
        filesep 'projects' filesep 'exoMetDN' filesep 'results' filesep 'codeResults' filesep 'multidimensionalModelGeneration'];
    pathSave = ['~' filesep 'work' filesep 'sbgCloud' filesep 'programReconstruction' ...
        filesep 'projects' filesep 'exoMetDN' filesep 'results' filesep 'codeResults' filesep 'iDN1'];
    matFileName = ['multidimensionalComparisonStats' param.approach];
    
else
    modelsDir = ['~' filesep 'work' filesep 'sbgCloud' filesep 'programReconstruction' ...
        filesep 'projects' filesep 'exoMetDN' filesep 'results' filesep 'multidimensionalModelGeneration'];
    pathSave = ['~' filesep 'work' filesep 'sbgCloud' filesep 'programReconstruction' ...
        filesep 'projects' filesep 'exoMetDN' filesep 'results' filesep 'codeResults' filesep 'iDN1'];
    matFileName = ['multidimensionalComparisonStats' param.approach];
end

% Get a list of all files and folders in this folder.
directoriesWithModels = dir(modelsDir);
directoriesWithModels = struct2cell(directoriesWithModels([directoriesWithModels.isdir]));
directoriesWithModels = directoriesWithModels(1, 3:end)';

%% multidimentionalComparisonStats

% Prepare the table with the accuracy data
objectives =  {'unWeighted0norm'; 'Weighted0normGE'; 'unWeighted1norm'; 'Weighted1normGE';...
    'unWeighted2norm'; 'Weighted2normGE'; 'unWeightedTCBMflux'};

nRows = length(directoriesWithModels) * length(objectives);
varTypes = {'double', 'string', 'string', 'string', 'string', 'string',...
    'string', 'string', 'string', 'string', 'double', 'double', 'double',...
    'double', 'double', 'double', 'double', 'double', 'double', 'double', ...
    'double', 'double', 'logical', 'string'};
varNames = {'modelId', 'dirName', 'tissueSpecificSolver', 'activeGenesApproach',...
    'transcriptomicThreshold', 'limitBounds', 'genesTranscriptomics', 'ions', ...
    'preferenceCurationOrOmics', 'objective', 'qualitativeBoth', 'quantitativeBoth',...
    'spearmanBoth', 'qualitativeModelSec', 'quantitativeModelSec', 'spearmanModelSec', ...
    'quantitativeModelUpt', 'qualitativeModelUpt', 'spearmanModelUpt', 'nOfmets', ...
    'nOfrxns', 'rankOfS', 'ATPtm', 'ME'};
multidimensionalComparisonStats = table('Size', [nRows length(varTypes)], 'VariableTypes', varTypes,...
    'VariableNames', varNames);

% Check if the comparison has already been performed
if ~recompute && isfile([pathSave filesep matFileName '.mat'])
    load([pathSave filesep matFileName '.mat'])
else
    disp('Testing qualitative and quantitative predictive capacity ...')
    
    c = 0;
    for i = 1:size(directoriesWithModels, 1)
        
        workingDirectory = [modelsDir filesep directoriesWithModels{i} filesep];
                   
        % Check if the model was already generated
        if isfile([workingDirectory 'Model.mat'])
            
            % Identify number dimensions
            load([workingDirectory 'Model.mat'])
            model = Model;
            numberOfMets = length(model.mets);
            numberOfRxns = length(model.rxns);
            if 0
                rankOfS = rank(full(model.S));
            else
                rankOfS = getRankLUSOL(model.S);
            end
            
            if isfile([workingDirectory 'accuracy' param.approach '.mat'])
                load([workingDirectory 'accuracy' param.approach '.mat'], 'comparisonData')
                if 0 && all(ismissing(comparisonData.fullReport.messages))
                    recompute = 0;
                else
                    delete([workingDirectory 'accuracy' param.approach '.mat'])
                    recompute = 1;
                end
            end
            
%             if isfile([workingDirectory 'accuracy.mat'])
%                 movefile([workingDirectory 'accuracy.mat'],[workingDirectory 'accuracy' param.approach '.mat'])
%             end
                
            % Compute or load the comparisonData
            if isfile([workingDirectory 'accuracy' param.approach '.mat'])
                disp([directoriesWithModels{i} filesep 'accuracy' param.approach '.mat exists already without error messages'])
                load([workingDirectory 'accuracy' param.approach '.mat'], 'comparisonData')
            else
                disp([directoriesWithModels{i} filesep 'accuracy' param.approach '.mat being computed'])
                
                % model predictive capacity parameters
                param.tests = 'flux';
                param.activeInactiveRxn = model.activeInactiveRxn;
                param.presentAbsentMet = model.presentAbsentMet;
                param.trainingSet = model.XomicsToModelSpecificData.exoMet;
                param.objectives = objectives;
                param.printLevel = 0;
               
                
                % test modelPredictiveCapacity
                [comparisonData, summary] = modelPredictiveCapacity(model, param);
                if ~all(ismissing(comparisonData.fullReport.messages))
                    warning([directoriesWithModels{i} filesep 'comparisonData.fullReport in accuracy.mat contains some error messages'])
                end
                save([workingDirectory 'accuracy' param.approach '.mat'], 'comparisonData', 'summary')
            end
            
            % Split conditions
            directoriesComparison = split(directoriesWithModels{i}, '_');
            
            for j = 1:length(objectives)
                
                c = c + 1;
                
                % Assign conditions
                multidimensionalComparisonStats.modelId(c) = i;
                multidimensionalComparisonStats.dirName(c) = directoriesWithModels{i};
                idIdx = ismember(directoriesComparison, {'fastCore'; 'thermoKernel'});
                multidimensionalComparisonStats.tissueSpecificSolver(c) = directoriesComparison(idIdx);
                idIdx = ismember(directoriesComparison, {'deleteModelGenes', 'oneRxnPerActiveGene'});
                multidimensionalComparisonStats.activeGenesApproach(c) = directoriesComparison(idIdx);
                idIdx = contains(directoriesComparison, {'transcriptomicsT'});
                multidimensionalComparisonStats.transcriptomicThreshold(c) = directoriesComparison(idIdx);
                idIdx = contains(directoriesComparison, {'limitBoundary'});
                multidimensionalComparisonStats.limitBounds(c) = directoriesComparison(idIdx);
                idIdx = contains(directoriesComparison, {'nactiveGenesT'});
                multidimensionalComparisonStats.genesTranscriptomics(c) = directoriesComparison(idIdx);
                idIdx = contains(directoriesComparison, {'Ions'});
                multidimensionalComparisonStats.ions(c) = directoriesComparison(idIdx);
                idIdx = ismember(directoriesComparison, {'curationOverOmics', 'omicsOverCuration'});
                multidimensionalComparisonStats.preferenceCurationOrOmics(c) = directoriesComparison(idIdx);
                
                % Assign objective
                multidimensionalComparisonStats.objective(c) = objectives(j);
                
                % Quantitative and qualitative
                multidimensionalComparisonStats.qualitativeBoth(c) = comparisonData.comparisonStats.qualAccuracy(strcmp(comparisonData.comparisonStats.model, 'both') & strcmp(comparisonData.comparisonStats.objective, objectives{j}));
                multidimensionalComparisonStats.quantitativeBoth(c) = comparisonData.comparisonStats.wEuclidNorm(strcmp(comparisonData.comparisonStats.model, 'both') & strcmp(comparisonData.comparisonStats.objective, objectives{j}));
                multidimensionalComparisonStats.spearmanBoth(c) = comparisonData.comparisonStats.Spearman(strcmp(comparisonData.comparisonStats.model, 'both') & strcmp(comparisonData.comparisonStats.objective, objectives{j}));
                multidimensionalComparisonStats.qualitativeModelSec(c) = comparisonData.comparisonStats.qualAccuracy(strcmp(comparisonData.comparisonStats.model, 'modelSec') & strcmp(comparisonData.comparisonStats.objective, objectives{j}));
                multidimensionalComparisonStats.quantitativeModelSec(c) = comparisonData.comparisonStats.wEuclidNorm(strcmp(comparisonData.comparisonStats.model, 'modelSec') & strcmp(comparisonData.comparisonStats.objective, objectives{j}));
                multidimensionalComparisonStats.spearmanModelSec(c) = comparisonData.comparisonStats.Spearman(strcmp(comparisonData.comparisonStats.model, 'modelSec') & strcmp(comparisonData.comparisonStats.objective, objectives{j}));
                multidimensionalComparisonStats.qualitativeModelUpt(c) = comparisonData.comparisonStats.qualAccuracy(strcmp(comparisonData.comparisonStats.model, 'modelUpt') & strcmp(comparisonData.comparisonStats.objective, objectives{j}));
                multidimensionalComparisonStats.quantitativeModelUpt(c) = comparisonData.comparisonStats.wEuclidNorm(strcmp(comparisonData.comparisonStats.model, 'modelUpt') & strcmp(comparisonData.comparisonStats.objective, objectives{j}));
                multidimensionalComparisonStats.spearmanModelUpt(c) = comparisonData.comparisonStats.Spearman(strcmp(comparisonData.comparisonStats.model, 'modelUpt') & strcmp(comparisonData.comparisonStats.objective, objectives{j}));
                
                if isnan(comparisonData.comparisonStats.Spearman(strcmp(comparisonData.comparisonStats.model, 'modelUpt') & strcmp(comparisonData.comparisonStats.objective, objectives{j})))
                    disp(workingDirectory)
                end
                % Error messages
                objectiveBool = contains(comparisonData.fullReport.objective, objectives(j));
                ME = unique(rmmissing(comparisonData.fullReport.messages(objectiveBool)));
                if ~isempty(ME)
                    multidimensionalComparisonStats.ME(c) = strjoin(unique(rmmissing(comparisonData.fullReport.messages(objectiveBool))));
                else
                    multidimensionalComparisonStats.ME(c) = 'noError';
                end
                
                % Dimensions
                multidimensionalComparisonStats.nOfmets(c) = numberOfMets;
                multidimensionalComparisonStats.nOfrxns(c) = numberOfRxns;
                multidimensionalComparisonStats.rankOfS(c) = rankOfS;
                multidimensionalComparisonStats.ATPtm(c) = ismember('ATPtm', model.rxns);
                
            end
            
        else % A model wasn't generated
            
            % Split conditions
            directoriesComparison = split(directoriesWithModels{i}, '_');
            
            for j = 1:length(objectives)
                
                c = c + 1;
                
                % Assign conditions
                multidimensionalComparisonStats.modelId(c) = i;
                multidimensionalComparisonStats.dirName(c) = directoriesWithModels{i};
                idIdx = ismember(directoriesComparison, {'fastCore'; 'thermoKernel'});
                multidimensionalComparisonStats.tissueSpecificSolver(c) = directoriesComparison(idIdx);
                idIdx = ismember(directoriesComparison, {'deleteModelGenes', 'oneRxnPerActiveGene'});
                multidimensionalComparisonStats.activeGenesApproach(c) = directoriesComparison(idIdx);
                idIdx = contains(directoriesComparison, {'transcriptomicsT'});
                multidimensionalComparisonStats.transcriptomicThreshold(c) = directoriesComparison(idIdx);
                idIdx = contains(directoriesComparison, {'limitBoundary'});
                multidimensionalComparisonStats.limitBounds(c) = directoriesComparison(idIdx);
                idIdx = contains(directoriesComparison, {'nactiveGenesT'});
                multidimensionalComparisonStats.genesTranscriptomics(c) = directoriesComparison(idIdx);
                idIdx = contains(directoriesComparison, {'Ions'});
                multidimensionalComparisonStats.ions(c) = directoriesComparison(idIdx);
                idIdx = ismember(directoriesComparison, {'curationOverOmics', 'omicsOverCuration'});
                multidimensionalComparisonStats.preferenceCurationOrOmics(c) = directoriesComparison(idIdx);
                
                % Assign objective
                multidimensionalComparisonStats.objective(c) = objectives(j);
                
                % Quantitative and qualitative
                multidimensionalComparisonStats.qualitativeBoth(c) = NaN;
                multidimensionalComparisonStats.quantitativeBoth(c) = NaN;
                multidimensionalComparisonStats.spearmanBoth(c) = NaN;
                multidimensionalComparisonStats.qualitativeModelSec(c) = NaN;
                multidimensionalComparisonStats.quantitativeModelSec(c) = NaN;
                multidimensionalComparisonStats.spearmanModelSec(c) = NaN;
                multidimensionalComparisonStats.qualitativeModelUpt(c) = NaN;
                multidimensionalComparisonStats.quantitativeModelUpt(c) = NaN;
                multidimensionalComparisonStats.spearmanModelUpt(c) = NaN;
                
                % Error messages
                multidimensionalComparisonStats.ME(c) = 'The model was not created';
                
                % Dimensions
                multidimensionalComparisonStats.nOfmets(c) = NaN;
                multidimensionalComparisonStats.nOfrxns(c) = NaN;
                multidimensionalComparisonStats.rankOfS(c) = NaN;
            end
        end
    end
    if ~exist(pathSave,'dir')
        mkdir(pathSave)
    end
    save([pathSave filesep matFileName '.mat'], 'multidimensionalComparisonStats')
end


disp('Model''s predictive capacity tested')
disp('Results saved in:')
disp([pathSave filesep matFileName '.mat'])

%% Test
if 0
    r = randi([1, length(directoriesWithModels)] , 10, 1);
    for i = 1:10
        
        workingDirectory = [modelsDir filesep directoriesWithModels{r(i)} filesep];
        
        load([workingDirectory 'Model.mat'])
        load([workingDirectory 'accuracy.mat'])
        
        comparisonDataBool = strcmp(comparisonData.comparisonStats.model, 'both');
        randomModelAccuracy = comparisonData.comparisonStats.qualAccuracy(comparisonDataBool);
        randomModelAccuracy(isnan(randomModelAccuracy)) = [];
        
        mdcsBool = strcmp(multidimensionalComparisonStats.dirName, directoriesWithModels{r(i)});
        mdcsAccuracy = multidimensionalComparisonStats.qualitativeBoth(mdcsBool);
        mdcsAccuracy(isnan(mdcsAccuracy)) = [];
        
        assert(isequal(sort(mdcsAccuracy), sort(randomModelAccuracy)), 'The accuracy is different')
        
    end
end