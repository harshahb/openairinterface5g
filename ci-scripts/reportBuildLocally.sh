#!/bin/bash
#/*
# * Licensed to the OpenAirInterface (OAI) Software Alliance under one or more
# * contributor license agreements.  See the NOTICE file distributed with
# * this work for additional information regarding copyright ownership.
# * The OpenAirInterface Software Alliance licenses this file to You under
# * the OAI Public License, Version 1.1  (the "License"); you may not use this file
# * except in compliance with the License.
# * You may obtain a copy of the License at
# *
# *      http://www.openairinterface.org/?page_id=698
# *
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.
# *-------------------------------------------------------------------------------
# * For more information about the OpenAirInterface (OAI) Software Alliance:
# *      contact@openairinterface.org
# */

function report_build_usage {
    echo "OAI CI VM script"
    echo "   Original Author: Raphael Defosseux"
    echo ""
    echo "Usage:"
    echo "------"
    echo "    oai-ci-vm-tool report-build [OPTIONS]"
    echo ""
    command_options_usage

}

function trigger_usage {
    echo "OAI CI VM script"
    echo "   Original Author: Raphael Defosseux"
    echo ""
    echo "    --trigger merge-request OR -mr"
    echo "    --trigger push          OR -pu"
    echo "    Specify trigger action of the Jenkins job. Either a merge-request event or a push event."
    echo ""
}

function details_table {
    echo "   <h4>$1</h4>" >> $3

    echo "   <table border = \"1\">" >> $3
    echo "      <tr bgcolor = \"#33CCFF\" >" >> $3
    echo "        <th>File</th>" >> $3
    echo "        <th>Line Number</th>" >> $3
    echo "        <th>Status</th>" >> $3
    echo "        <th>Message</th>" >> $3
    echo "      </tr>" >> $3

    LIST_MESSAGES=`egrep "error:|warning:" $2 | egrep -v "jobserver unavailable|Clock skew detected.|flexran.proto|disabling jobserver mode"`
    COMPLETE_MESSAGE="start"
    for MESSAGE in $LIST_MESSAGES
    do
        if [[ $MESSAGE == *"/home/ubuntu/tmp"* ]] || [[  $MESSAGE == *"/tmp/CI-eNB"* ]]
        then
            FILENAME=`echo $MESSAGE | sed -e "s#^/home/ubuntu/tmp/##" -e "s#^.*/tmp/CI-eNB/##" | awk -F ":" '{print $1}'`
            LINENB=`echo $MESSAGE | awk -F ":" '{print $2}'`
            if [ "$COMPLETE_MESSAGE" != "start" ]
            then
                COMPLETE_MESSAGE=`echo $COMPLETE_MESSAGE | sed -e "s#‘#'#g" -e "s#’#'#g"`
                echo "        <td>$COMPLETE_MESSAGE</td>" >> $3
                echo "      </tr>" >> $3
            fi
            echo "      <tr>" >> $3
            echo "        <td>$FILENAME</td>" >> $3
            echo "        <td>$LINENB</td>" >> $3
        else
            if [[ $MESSAGE == *"warning:"* ]] || [[ $MESSAGE == *"error:"* ]]
            then
                MSGTYPE=`echo $MESSAGE | sed -e "s#:##g"`
                echo "        <td>$MSGTYPE</td>" >> $3
                COMPLETE_MESSAGE=""
            else
                COMPLETE_MESSAGE=$COMPLETE_MESSAGE" "$MESSAGE
            fi
        fi
    done

    if [ "$COMPLETE_MESSAGE" != "start" ]
    then
        COMPLETE_MESSAGE=`echo $COMPLETE_MESSAGE | sed -e "s#‘#'#g" -e "s#’#'#g"`
        echo "        <td>$COMPLETE_MESSAGE</td>" >> $3
        echo "      </tr>" >> $3
    fi
    echo "   </table>" >> $3
}

function summary_table_header {
    echo "   <h3>$1</h3>" >> ./build_results.html
    if [ -f $2/build_final_status.log ]
    then
        if [ `grep -c COMMAND $2/build_final_status.log` -eq 1 ]
        then
            COMMAND=`grep COMMAND $2/build_final_status.log | sed -e "s#COMMAND: ##"`
        else
            COMMAND="Unknown"
        fi
        if [ `grep -c BUILD_OK $2/build_final_status.log` -eq 1 ]
        then
            echo "   <div class=\"alert alert-success\">" >> ./build_results.html
            echo "      <span class=\"glyphicon glyphicon-expand\"></span> $COMMAND <span class=\"glyphicon glyphicon-arrow-right\"></span> " >> ./build_results.html
            echo "      <strong>BUILD was SUCCESSFUL <span class=\"glyphicon glyphicon-ok-circle\"></span></strong>" >> ./build_results.html
            echo "   </div>" >> ./build_results.html
        else
            echo "   <div class=\"alert alert-danger\">" >> ./build_results.html
            echo "      <span class=\"glyphicon glyphicon-expand\"></span> $COMMAND <span class=\"glyphicon glyphicon-arrow-right\"></span> " >> ./build_results.html
            echo "      <strong>BUILD was a FAILURE! <span class=\"glyphicon glyphicon-ban-circle\"></span></strong>" >> ./build_results.html
            echo "   </div>" >> ./build_results.html
        fi
    else
        echo "   <div class=\"alert alert-danger\">" >> ./build_results.html
        echo "      <strong>COULD NOT DETERMINE BUILD FINAL STATUS! <span class=\"glyphicon glyphicon-ban-circle\"></span></strong>" >> ./build_results.html
        echo "   </div>" >> ./build_results.html
    fi
    echo "   <table border = \"1\">" >> ./build_results.html
    echo "      <tr bgcolor = \"#33CCFF\" >" >> ./build_results.html
    echo "        <th>Element</th>" >> ./build_results.html
    echo "        <th>Status</th>" >> ./build_results.html
    echo "        <th>Nb Errors</th>" >> ./build_results.html
    echo "        <th>Nb Warnings</th>" >> ./build_results.html
    echo "      </tr>" >> ./build_results.html
}

function summary_table_row {
    echo "      <tr>" >> ./build_results.html
    echo "        <td bgcolor = \"lightcyan\" >$1</th>" >> ./build_results.html
    if [ -f $2 ]
    then
        BUILD_STATUS=`egrep -c "$3" $2`
        if [ $BUILD_STATUS -eq 1 ]
        then
            echo "        <td bgcolor = \"green\" >OK</th>" >> ./build_results.html
        else
            echo "        <td bgcolor = \"red\" >KO</th>" >> ./build_results.html
        fi
        NB_ERRORS=`egrep -c "error:" $2`
        if [ $NB_ERRORS -eq 0 ]
        then
            echo "        <td bgcolor = \"green\" >$NB_ERRORS</th>" >> ./build_results.html
        else
            echo "        <td bgcolor = \"red\" >$NB_ERRORS</th>" >> ./build_results.html
        fi
        NB_WARNINGS=`egrep "warning:" $2 | egrep -v "jobserver unavailable|Clock skew detected.|flexran.proto|disabling jobserver mode" | egrep -c "warning:"`
        if [ $NB_WARNINGS -eq 0 ]
        then
            echo "        <td bgcolor = \"green\" >$NB_WARNINGS</th>" >> ./build_results.html
        else
            if [ $NB_WARNINGS -gt 20 ]
            then
                echo "        <td bgcolor = \"red\" >$NB_WARNINGS</th>" >> ./build_results.html
            else
                echo "        <td bgcolor = \"orange\" >$NB_WARNINGS</th>" >> ./build_results.html
            fi
        fi
        if [ $NB_ERRORS -ne 0 ] || [ $NB_WARNINGS -ne 0 ]
        then
            details_table "$1" $2 $4
        fi
    else
        echo "        <td bgcolor = \"lightgray\" >Unknown</th>" >> ./build_results.html
        echo "        <td bgcolor = \"lightgray\" >--</th>" >> ./build_results.html
        echo "        <td bgcolor = \"lightgray\" >--</th>" >> ./build_results.html
    fi
    echo "      </tr>" >> ./build_results.html
}

function summary_table_footer {
    echo "   </table>" >> ./build_results.html
}

function sca_summary_table_header {
    echo "   <h3>$2</h3>" >> ./build_results.html
    NB_ERRORS=`egrep -c "severity=\"error\"" $1`
    NB_WARNINGS=`egrep -c "severity=\"warning\"" $1`
    ADDED_ERRORS="0"
    ADDED_WARNINGS="0"
    FINAL_LOG=`echo $1 | sed -e "s#cppcheck\.xml#build_final_status.log#"`
    if [ `grep -c COMMAND $FINAL_LOG` -eq 1 ]
    then
        COMMAND=`grep COMMAND $FINAL_LOG | sed -e "s#COMMAND: ##"`
    else
        COMMAND="Unknown"
    fi
    if [ $MR_TRIG -eq 1 ]
    then
        if [ -d ../../cppcheck_archives ]
        then
            if [ -d ../../cppcheck_archives/$JOB_NAME ]
            then
                ADDED_ERRORS=`diff $1 ../../cppcheck_archives/$JOB_NAME/cppcheck.xml | egrep --color=never "^<" | egrep -c "severity=\"error"`
                ADDED_WARNINGS=`diff $1 ../../cppcheck_archives/$JOB_NAME/cppcheck.xml | egrep --color=never "^<" | egrep -c "severity=\"warning"`
            fi
        fi
        local TOTAL_NUMBER=$[$ADDED_ERRORS+$ADDED_WARNINGS]
        if [ -f $JENKINS_WKSP/oai_cppcheck_added_errors.txt ]; then rm -f $JENKINS_WKSP/oai_cppcheck_added_errors.txt; fi
        echo "$TOTAL_NUMBER" > $JENKINS_WKSP/oai_cppcheck_added_errors.txt
    fi
    if [ $NB_ERRORS -eq 0 ] && [ $NB_WARNINGS -eq 0 ]
    then
        echo "   <div class=\"alert alert-success\">" >> ./build_results.html
        echo "      <span class=\"glyphicon glyphicon-expand\"></span> $COMMAND <br><br>" >> ./build_results.html
        echo "      <strong>CPPCHECK found NO error and NO warning <span class=\"glyphicon glyphicon-ok-circle\"></span></strong>" >> ./build_results.html
        echo "   </div>" >> ./build_results.html
    else
        if [ $NB_ERRORS -eq 0 ]
        then
            echo "   <div class=\"alert alert-warning\">" >> ./build_results.html
            echo "      <span class=\"glyphicon glyphicon-expand\"></span> $COMMAND <br><br>" >> ./build_results.html
            if [ $PU_TRIG -eq 1 ]
            then
                echo "      <strong>CPPCHECK found NO error and $NB_WARNINGS warnings <span class=\"glyphicon glyphicon-warning-sign\"></span></strong>" >> ./build_results.html
            fi
            if [ $MR_TRIG -eq 1 ]
            then
                if [ $ADDED_WARNINGS -eq 0 ]
                then
                    echo "      <strong>CPPCHECK found NO error and $NB_WARNINGS warnings <span class=\"glyphicon glyphicon-warning-sign\"></span></strong>" >> ./build_results.html
                else
                    echo "      <strong>CPPCHECK found NO error and $NB_WARNINGS warnings <span class=\"glyphicon glyphicon-warning-sign\"></span></strong>" >> ./build_results.html
                fi
            fi
            echo "   </div>" >> ./build_results.html
        else
            echo "   <div class=\"alert alert-danger\">" >> ./build_results.html
            echo "      <span class=\"glyphicon glyphicon-expand\"></span> $COMMAND <br><br>" >> ./build_results.html
            if [ $PU_TRIG -eq 1 ]
            then
                echo "      <strong>CPPCHECK found $NB_ERRORS errors and $NB_WARNINGS warnings <span class=\"glyphicon glyphicon-ban-circle\"></span></strong>" >> ./build_results.html
            fi
            if [ $MR_TRIG -eq 1 ]
            then
                if [ $ADDED_ERRORS -eq 0 ] && [ $ADDED_WARNINGS -eq 0 ]
                then
                    echo "      <strong>CPPCHECK found $NB_ERRORS errors and $NB_WARNINGS warnings <span class=\"glyphicon glyphicon-ban-circle\"></span></strong>" >> ./build_results.html
                else
                    echo "      <strong>CPPCHECK found $NB_ERRORS errors and $NB_WARNINGS warnings <span class=\"glyphicon glyphicon-ban-circle\"></span>" >> ./build_results.html
                    echo "      <br>" >> ./build_results.html
                    echo "      <br>" >> ./build_results.html
                    echo "      <span class=\"glyphicon glyphicon-alert\"></span> This Merge Request may have introduced up to $ADDED_ERRORS errors and $ADDED_WARNINGS warnings. <span class=\"glyphicon glyphicon-alert\"></span></strong>" >> ./build_results.html
                fi
            fi
            echo "   </div>" >> ./build_results.html
        fi
    fi
    if [ $PU_TRIG -eq 1 ]
    then
        if [ -d ../../cppcheck_archives ]
        then
            if [ -d ../../cppcheck_archives/$JOB_NAME ]
            then
                cp $1 ../../cppcheck_archives/$JOB_NAME
            fi
        fi
    fi
    echo "   <button data-toggle=\"collapse\" data-target=\"#oai-cppcheck-details\">More details on CPPCHECK results</button>" >> ./build_results.html
    echo "   <div id=\"oai-cppcheck-details\" class=\"collapse\">" >> ./build_results.html
    echo "   <br>" >> ./build_results.html
    echo "   <table border = \"1\">" >> ./build_results.html
    echo "      <tr bgcolor = \"#33CCFF\" >" >> ./build_results.html
    echo "        <th>Error / Warning Type</th>" >> ./build_results.html
    echo "        <th>Nb Errors</th>" >> ./build_results.html
    echo "        <th>Nb Warnings</th>" >> ./build_results.html
    echo "      </tr>" >> ./build_results.html
    echo "0" > ccp_error_cnt.txt
}

function sca_summary_table_row {
    echo "      <tr>" >> ./build_results.html
    echo "        <td bgcolor = \"lightcyan\" >$2</td>" >> ./build_results.html
    if [ -f $1 ]
    then
        NB_ERRORS=`egrep "severity=\"error\"" $1 | egrep -c "id=\"$3\""`
        echo "        <td>$NB_ERRORS</td>" >> ./build_results.html
        echo "        <td>N/A</td>" >> ./build_results.html
        if [ -f ccp_error_cnt.txt ]
        then
            TOTAL_ERRORS=`cat ccp_error_cnt.txt`
            TOTAL_ERRORS=$((TOTAL_ERRORS + NB_ERRORS))
            echo $TOTAL_ERRORS > ccp_error_cnt.txt
        fi
    else
        echo "        <td>Unknown</td>" >> ./build_results.html
        echo "        <td>Unknown</td>" >> ./build_results.html
    fi
    echo "      </tr>" >> ./build_results.html
}

function sca_summary_table_footer {
    if [ -f $1 ]
    then
        NB_ERRORS=`egrep -c "severity=\"error\"" $1`
        NB_WARNINGS=`egrep -c "severity=\"warning\"" $1`
        if [ -f ccp_error_cnt.txt ]
        then
            echo "      <tr>" >> ./build_results.html
            echo "        <td bgcolor = \"lightcyan\" >Others</td>" >> ./build_results.html
            TOTAL_ERRORS=`cat ccp_error_cnt.txt`
            TOTAL_ERRORS=$((NB_ERRORS - TOTAL_ERRORS))
            echo "        <td>$TOTAL_ERRORS</td>" >> ./build_results.html
            echo "        <td>$NB_WARNINGS</td>" >> ./build_results.html
            echo "      </tr>" >> ./build_results.html
            rm -f ccp_error_cnt.txt
        fi
        echo "      <tr bgcolor = \"#33CCFF\" >" >> ./build_results.html
        echo "        <th>Total</th>" >> ./build_results.html
        echo "        <th>$NB_ERRORS</th>" >> ./build_results.html
        echo "        <th>$NB_WARNINGS</th>" >> ./build_results.html
    else
        echo "      <tr bgcolor = \"#33CCFF\"  >" >> ./build_results.html
        echo "        <th>Total</th>" >> ./build_results.html
        echo "        <th>Unknown</th>" >> ./build_results.html
        echo "        <th>Unknown</th>" >> ./build_results.html
        if [ -f ccp_error_cnt.txt ]
        then
            rm -f ccp_error_cnt.txt
        fi
    fi
    echo "      </tr>" >> ./build_results.html
    echo "   </table>" >> ./build_results.html
    echo "   <p>Full details in zipped artifact (cppcheck/cppcheck.xml) </p>" >> ./build_results.html
    echo "   <p style=\"margin-left: 30px\">Graphical Interface tool : <strong><code>cppcheck-gui -l cppcheck/cppcheck.xml</code></strong></p>" >> ./build_results.html

    if [ $MR_TRIG -eq 1 ]
    then
        if [ $ADDED_ERRORS -ne 0 ] || [ $ADDED_WARNINGS -ne 0 ]
        then
            echo "   <table border = \"1\">" >> ./build_results.html
            echo "      <tr bgcolor = \"#33CCFF\" >" >> ./build_results.html
            echo "        <th>Potential File(s) impacted by added errors/warnings</th>" >> ./build_results.html
            echo "        <th>Line Number</th>" >> ./build_results.html
            echo "        <th>Severity</th>" >> ./build_results.html
            echo "        <th>Message</th>" >> ./build_results.html
            echo "      </tr>" >> ./build_results.html
            SEVERITY="none"
            POTENTIAL_FILES=`diff $1  ../../cppcheck_archives/$JOB_NAME/cppcheck.xml | egrep --color=never "^<" | egrep "location file|severity" | sed -e "s# #@#g"`
            for POT_FILE in $POTENTIAL_FILES
            do
                if [ `echo $POT_FILE | grep -c location` -eq 1 ]
                then
                    FILENAME=`echo $POT_FILE | sed -e "s#^.*file=\"##" -e "s#\"@line.*/>##"`
                    LINE=`echo $POT_FILE | sed -e "s#^.*line=\"##" -e "s#\"/>##"`
                    if [[ $SEVERITY != *"none" ]]
                    then
                        echo "      <tr>" >> ./build_results.html
                        echo "        <td>$FILENAME</td>" >> ./build_results.html
                        echo "        <td>$LINE</td>" >> ./build_results.html
                        echo "        <td>$SEVERITY</td>" >> ./build_results.html
                        echo "        <td>$MESSAGE</td>" >> ./build_results.html
                        echo "      </tr>" >> ./build_results.html
                    fi
                else
                    SEVERITY=`echo $POT_FILE | sed -e "s#^.*severity=\"##" -e "s#\"@msg=.*##"`
                    MESSAGE=`echo $POT_FILE | sed -e "s#^.*msg=\"##" -e "s#\"@verbose=.*##" -e "s#@# #g"`
                fi
            done
            echo "   </table>" >> ./build_results.html
        fi
    fi
    echo "   </div>" >> ./build_results.html
}

function report_build {
    echo "############################################################"
    echo "OAI CI VM script"
    echo "############################################################"

    echo "JENKINS_WKSP        = $JENKINS_WKSP"
    echo "GIT_URL             = $GIT_URL"

    cd ${JENKINS_WKSP}
    echo "<!DOCTYPE html>" > ./build_results.html
    echo "<html class=\"no-js\" lang=\"en-US\">" >> ./build_results.html
    echo "<head>" >> ./build_results.html
    echo "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">" >> ./build_results.html
    echo "  <link rel=\"stylesheet\" href=\"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css\">" >> ./build_results.html
    echo "  <script src=\"https://ajax.googleapis.com/ajax/libs/jquery/3.3.1/jquery.min.js\"></script>" >> ./build_results.html
    echo "  <script src=\"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js\"></script>" >> ./build_results.html
    echo "  <title>Build Results for $JOB_NAME job build #$BUILD_ID</title>" >> ./build_results.html
    echo "  <base href = \"http://www.openairinterface.org/\" />" >> ./build_results.html
    echo "</head>" >> ./build_results.html
    echo "<body><div class=\"container\">" >> ./build_results.html
    echo "  <br>" >> ./build_results.html
    echo "  <table style=\"border-collapse: collapse; border: none;\">" >> ./build_results.html
    echo "    <tr style=\"border-collapse: collapse; border: none;\">" >> ./build_results.html
    echo "      <td style=\"border-collapse: collapse; border: none;\">" >> ./build_results.html
    echo "        <a href=\"http://www.openairinterface.org/\">" >> ./build_results.html
    echo "           <img src=\"/wp-content/uploads/2016/03/cropped-oai_final_logo2.png\" alt=\"\" border=\"none\" height=50 width=150>" >> ./build_results.html
    echo "           </img>" >> ./build_results.html
    echo "        </a>" >> ./build_results.html
    echo "      </td>" >> ./build_results.html
    echo "      <td style=\"border-collapse: collapse; border: none; vertical-align: center;\">" >> ./build_results.html
    echo "        <b><font size = \"6\">Job Summary -- Job: $JOB_NAME -- Build-ID: $BUILD_ID</font></b>" >> ./build_results.html
    echo "      </td>" >> ./build_results.html
    echo "    </tr>" >> ./build_results.html
    echo "  </table>" >> ./build_results.html
    echo "  <br>" >> ./build_results.html
    echo "   <table border = \"1\">" >> ./build_results.html
    echo "      <tr>" >> ./build_results.html
    echo "        <td bgcolor = \"lightcyan\" > <span class=\"glyphicon glyphicon-time\"></span> Build Start Time (UTC)</td>" >> ./build_results.html
    echo "        <td>TEMPLATE_BUILD_TIME</td>" >> ./build_results.html
    echo "      </tr>" >> ./build_results.html
    echo "      <tr>" >> ./build_results.html
    echo "        <td bgcolor = \"lightcyan\" > <span class=\"glyphicon glyphicon-cloud-upload\"></span> GIT Repository</td>" >> ./build_results.html
    echo "        <td><a href=\"$GIT_URL\">$GIT_URL</a></td>" >> ./build_results.html
    echo "      </tr>" >> ./build_results.html
    echo "      <tr>" >> ./build_results.html
    echo "        <td bgcolor = \"lightcyan\" > <span class=\"glyphicon glyphicon-wrench\"></span> Job Trigger</td>" >> ./build_results.html
    if [ $PU_TRIG -eq 1 ]; then echo "        <td>Push Event</td>" >> ./build_results.html; fi
    if [ $MR_TRIG -eq 1 ]; then echo "        <td>Merge-Request</td>" >> ./build_results.html; fi
    echo "      </tr>" >> ./build_results.html
    if [ $PU_TRIG -eq 1 ]
    then
        echo "      <tr>" >> ./build_results.html
        echo "        <td bgcolor = \"lightcyan\" > <span class=\"glyphicon glyphicon-tree-deciduous\"></span> Branch</td>" >> ./build_results.html
        echo "        <td>$SOURCE_BRANCH</td>" >> ./build_results.html
        echo "      </tr>" >> ./build_results.html
        echo "      <tr>" >> ./build_results.html
        echo "        <td bgcolor = \"lightcyan\" > <span class=\"glyphicon glyphicon-tag\"></span> Commit ID</td>" >> ./build_results.html
        echo "        <td>$SOURCE_COMMIT_ID</td>" >> ./build_results.html
        echo "      </tr>" >> ./build_results.html
        if [ -e .git/CI_COMMIT_MSG ]
        then
            echo "      <tr>" >> ./build_results.html
            echo "        <td bgcolor = \"lightcyan\" > <span class=\"glyphicon glyphicon-comment\"></span> Commit Message</td>" >> ./build_results.html
            MSG=`cat .git/CI_COMMIT_MSG`
            echo "        <td>$MSG</td>" >> ./build_results.html
            echo "      </tr>" >> ./build_results.html
        fi
    fi
    if [ $MR_TRIG -eq 1 ]
    then
        echo "      <tr>" >> ./build_results.html
        echo "        <td bgcolor = \"lightcyan\" > <span class=\"glyphicon glyphicon-log-out\"></span> Source Branch</td>" >> ./build_results.html
        echo "        <td>$SOURCE_BRANCH</td>" >> ./build_results.html
        echo "      </tr>" >> ./build_results.html
        echo "      <tr>" >> ./build_results.html
        echo "        <td bgcolor = \"lightcyan\" > <span class=\"glyphicon glyphicon-tag\"></span> Source Commit ID</td>" >> ./build_results.html
        echo "        <td>$SOURCE_COMMIT_ID</td>" >> ./build_results.html
        echo "      </tr>" >> ./build_results.html
        if [ -e .git/CI_COMMIT_MSG ]
        then
            echo "      <tr>" >> ./build_results.html
            echo "        <td bgcolor = \"lightcyan\" > <span class=\"glyphicon glyphicon-comment\"></span> Source Commit Message</td>" >> ./build_results.html
            MSG=`cat .git/CI_COMMIT_MSG`
            echo "        <td>$MSG</td>" >> ./build_results.html
            echo "      </tr>" >> ./build_results.html
        fi
        echo "      <tr>" >> ./build_results.html
        echo "        <td bgcolor = \"lightcyan\" > <span class=\"glyphicon glyphicon-log-in\"></span> Target Branch</td>" >> ./build_results.html
        echo "        <td>$TARGET_BRANCH</td>" >> ./build_results.html
        echo "      </tr>" >> ./build_results.html
        echo "      <tr>" >> ./build_results.html
        echo "        <td bgcolor = \"lightcyan\" > <span class=\"glyphicon glyphicon-tag\"></span> Target Commit ID</td>" >> ./build_results.html
        echo "        <td>$TARGET_COMMIT_ID</td>" >> ./build_results.html
        echo "      </tr>" >> ./build_results.html
    fi
    echo "   </table>" >> ./build_results.html
    echo "   <h2>Build Summary</h2>" >> ./build_results.html

    echo "   <h3>OAI Coding / Formatting Guidelines Check</h3>" >> ./build_results.html
    if [ -f ./header-files-w-incorrect-define.txt ]
    then
        NB_FILES_IN_ERROR=`wc -l ./header-files-w-incorrect-define.txt | sed -e "s@ .*@@"`
        if [ $NB_FILES_IN_ERROR -eq 0 ]
        then
            echo "   <div class=\"alert alert-success\">" >> ./build_results.html
            if [ $MR_TRIG -eq 1 ]; then echo "   <strong>No Issue for CIRCULAR DEPENDENCY PROTECTION in modified files</strong>" >> ./build_results.html; fi
            if [ $PU_TRIG -eq 1 ]; then echo "   <strong>No Issue for CIRCULAR DEPENDENCY PROTECTION in the whole repository</strong>" >> ./build_results.html; fi
            echo "   </div>" >> ./build_results.html
        else
            echo "   <div class=\"alert alert-warning\">" >> ./build_results.html
            if [ $MR_TRIG -eq 1 ]; then echo "   <strong>${NB_FILES_IN_ERROR} modified files MAY NOT HAVE CIRCULAR DEPENDENCY PROTECTION</strong>" >> ./build_results.html; fi
            if [ $PU_TRIG -eq 1 ]; then echo "   <strong>${NB_FILES_IN_ERROR} files in repository MAY NOT HAVE CIRCULAR DEPENDENCY PROTECTION in the whole repository</strong>" >> ./build_results.html; fi
            echo "   </div>" >> ./build_results.html
            echo "   <button data-toggle=\"collapse\" data-target=\"#oai-circular-details\">More details on circular dependency protection check</button>" >> ./build_results.html
            echo "   <div id=\"oai-circular-details\" class=\"collapse\">" >> ./build_results.html
            echo "   <table border = 1>" >> ./build_results.html
            echo "      <tr>" >> ./build_results.html
            echo "        <th bgcolor = \"lightcyan\" >Potential Issue</th>" >> ./build_results.html
            echo "        <th bgcolor = \"lightcyan\" >Impacted File</th>" >> ./build_results.html
            echo "        <th bgcolor = \"lightcyan\" >Incorrect Macro</th>" >> ./build_results.html
            echo "      </tr>" >> ./build_results.html
            awk '{if($0 ~/error in/){print "      <tr><td>error in declaration</td><td>"$4"</td><td>"$5"</td></tr>"};if($0 ~/files with same/){print "      <tr><td>files with same #define</td><td>"$5"</td><td>"$6"</td></tr>"}}' ./header-files-w-incorrect-define.txt >> ./build_results.html
            echo "   </table>" >> ./build_results.html
            echo "   </div>" >> ./build_results.html
            echo "   <br>" >> ./build_results.html
        fi
    fi
    if [ -f ./files-w-gnu-gpl-license-banner.txt ]
    then
        NB_FILES_IN_ERROR=`wc -l ./files-w-gnu-gpl-license-banner.txt | sed -e "s@ .*@@"`
        if [ $NB_FILES_IN_ERROR -ne 0 ]
        then
            echo "   <div class=\"alert alert-danger\">" >> ./build_results.html
            if [ $MR_TRIG -eq 1 ]; then echo "   <strong>${NB_FILES_IN_ERROR} modified files HAVE a GNU GPL license banner</strong>" >> ./build_results.html; fi
            if [ $PU_TRIG -eq 1 ]; then echo "   <strong>${NB_FILES_IN_ERROR} files in repository HAVE a GNU GPL license banner</strong>" >> ./build_results.html; fi
            echo "   </div>" >> ./build_results.html
            echo "   <button data-toggle=\"collapse\" data-target=\"#oai-license-gpl\">More details on GNU GPL license banner issue</button>" >> ./build_results.html
            echo "   <div id=\"oai-license-gpl\" class=\"collapse\">" >> ./build_results.html
            echo "   <table border = 1>" >> ./build_results.html
            echo "      <tr>" >> ./build_results.html
            echo "        <th bgcolor = \"lightcyan\" >Filename</th>" >> ./build_results.html
            echo "      </tr>" >> ./build_results.html
            awk '{print "      <tr><td>"$1"</td></tr>"}' ./files-w-gnu-gpl-license-banner.txt >> ./build_results.html
            echo "   </table>" >> ./build_results.html
            echo "   </div>" >> ./build_results.html
            echo "   <br>" >> ./build_results.html
        fi
    fi
    if [ -f ./files-w-suspect-banner.txt ]
    then
        NB_FILES_IN_ERROR=`wc -l ./files-w-suspect-banner.txt | sed -e "s@ .*@@"`
        if [ $NB_FILES_IN_ERROR -ne 0 ]
        then
            echo "   <div class=\"alert alert-warning\">" >> ./build_results.html
            if [ $MR_TRIG -eq 1 ]; then echo "   <strong>${NB_FILES_IN_ERROR} modified files HAVE a suspect license banner</strong>" >> ./build_results.html; fi
            if [ $PU_TRIG -eq 1 ]; then echo "   <strong>${NB_FILES_IN_ERROR} files in repository HAVE a suspect license banner</strong>" >> ./build_results.html; fi
            echo "   </div>" >> ./build_results.html
            echo "   <button data-toggle=\"collapse\" data-target=\"#oai-license-suspect\">More details on suspect banner files</button>" >> ./build_results.html
            echo "   <div id=\"oai-license-suspect\" class=\"collapse\">" >> ./build_results.html
            echo "   <table border = 1>" >> ./build_results.html
            echo "      <tr>" >> ./build_results.html
            echo "        <th bgcolor = \"lightcyan\" >Filename</th>" >> ./build_results.html
            echo "      </tr>" >> ./build_results.html
            awk '{print "      <tr><td>"$1"</td></tr>"}' ././files-w-suspect-banner.txt >> ./build_results.html
            echo "   </table>" >> ./build_results.html
            echo "   </div>" >> ./build_results.html
            echo "   <br>" >> ./build_results.html
        fi
    fi

    echo "   <h2>Ubuntu 16.04 LTS -- Summary</h2>" >> ./build_results.html

    summary_table_header "OAI Build: 4G LTE eNB -- USRP option" ./archives/enb_eth
    summary_table_row "LTE SoftModem - Release 15" ./archives/enb_eth/lte-softmodem.Rel15.txt "Built target lte-softmodem" ./enb_eth_row1.html
    summary_table_row "Coding - Release 15" ./archives/enb_eth/coding.Rel15.txt "Built target coding" ./enb_eth_row2.html
    summary_table_row "OAI ETHERNET transport - Release 15" ./archives/enb_eth/oai_eth_transpro.Rel15.txt "Built target oai_eth_transpro" ./enb_eth_row3.html
    summary_table_row "Parameters Lib Config - Release 15" ./archives/enb_eth/params_libconfig.Rel15.txt "Built target params_libconfig" ./enb_eth_row4.html
    summary_table_row "RF Simulator - Release 15" ./archives/enb_eth/rfsimulator.Rel15.txt "Built target rfsimulator" ./enb_eth_row5.html
    summary_table_row "OAI USRP device if - Release 15" ./archives/enb_eth/oai_usrpdevif.Rel15.txt "Built target oai_usrpdevif" ./enb_eth_row7.html
    summary_table_footer

    summary_table_header "OAI Build: 4G LTE UE -- USRP option" ./archives/ue_eth
    summary_table_row "LTE UE SoftModem - Release 15" ./archives/ue_eth/lte-uesoftmodem.Rel15.txt "Built target lte-uesoftmodem" ./ue_eth_row1.html
    summary_table_row "Coding - Release 15" ./archives/ue_eth/coding.Rel15.txt "Built target coding" ./ue_eth_row2.html
    summary_table_row "OAI ETHERNET transport - Release 15" ./archives/ue_eth/oai_eth_transpro.Rel15.txt "Built target oai_eth_transpro" ./ue_eth_row3.html
    summary_table_row "Parameters Lib Config - Release 15" ./archives/ue_eth/params_libconfig.Rel15.txt "Built target params_libconfig" ./ue_eth_row4.html
    summary_table_row "RF Simulator - Release 15" ./archives/ue_eth/rfsimulator.Rel15.txt "Built target rfsimulator" ./ue_eth_row5.html
    summary_table_row "Conf 2 UE Data - Release 15" ./archives/ue_eth/conf2uedata.Rel15.txt "Built target conf2uedata" ./ue_eth_row7.html
    summary_table_row "NVRAM - Release 15" ./archives/ue_eth/nvram.Rel15.txt "Built target nvram" ./ue_eth_row8.html
    summary_table_row "UE IP - Release 15" ./archives/ue_eth/ue_ip.Rel15.txt "Built target ue_ip" ./ue_eth_row9.html
    summary_table_row "USIM - Release 15" ./archives/ue_eth/usim.Rel15.txt "Built target usim" ./ue_eth_row9a.html
    summary_table_row "OAI USRP device if - Release 15" ./archives/ue_eth/oai_usrpdevif.Rel15.txt "Built target oai_usrpdevif" ./ue_eth_row9b.html
    summary_table_footer

    if [ -f archives/gnb_usrp/nr-softmodem.Rel15.txt ]
    then
        summary_table_header "OAI Build: 5G NR gNB -- USRP option" ./archives/gnb_usrp
        summary_table_row "5G NR SoftModem - Release 15" ./archives/gnb_usrp/nr-softmodem.Rel15.txt "Built target nr-softmodem" ./gnb_usrp_row1.html
        summary_table_row "Coding - Release 15" ./archives/gnb_usrp/coding.Rel15.txt "Built target coding" ./gnb_usrp_row2.html
        summary_table_row "OAI USRP device if - Release 15" ./archives/gnb_usrp/oai_usrpdevif.Rel15.txt "Built target oai_usrpdevif" ./gnb_usrp_row3.html
        summary_table_row "OAI ETHERNET transport - Release 15" ./archives/gnb_usrp/oai_eth_transpro.Rel15.txt "Built target oai_eth_transpro" ./gnb_usrp_row4.html
        summary_table_row "Parameters Lib Config - Release 15" ./archives/gnb_usrp/params_libconfig.Rel15.txt "Built target params_libconfig" ./gnb_usrp_row6.html
        summary_table_footer
    fi

    if [ -f archives/nr_ue_usrp/nr-uesoftmodem.Rel15.txt ]
    then
        summary_table_header "OAI Build: 5G NR UE -- USRP option" ./archives/nr_ue_usrp
        summary_table_row "5G NR UE SoftModem - Release 15" ./archives/nr_ue_usrp/nr-uesoftmodem.Rel15.txt "Built target nr-uesoftmodem" ./nr_ue_usrp_row1.html
        summary_table_row "Coding - Release 15" ./archives/nr_ue_usrp/coding.Rel15.txt "Built target coding" ./nr_ue_usrp_row2.html
        summary_table_row "OAI USRP device if - Release 15" ./archives/nr_ue_usrp/oai_usrpdevif.Rel15.txt "Built target oai_usrpdevif" ./nr_ue_usrp_row3.html
        summary_table_row "OAI ETHERNET transport - Release 15" ./archives/nr_ue_usrp/oai_eth_transpro.Rel15.txt "Built target oai_eth_transpro" ./nr_ue_usrp_row4.html
        summary_table_row "Parameters Lib Config - Release 15" ./archives/nr_ue_usrp/params_libconfig.Rel15.txt "Built target params_libconfig" ./nr_ue_usrp_row6.html
        summary_table_footer
    fi

    if [ -e ./archives/red_hat ]
    then
        echo "   <h2>Red Hat Enterprise Linux Server release 7.6) -- Summary</h2>" >> ./build_results.html

        summary_table_header "OAI Build: 4G LTE eNB -- USRP option (RHEL)" ./archives/red_hat
        summary_table_row "LTE SoftModem - Release 15" ./archives/red_hat/lte-softmodem.Rel15.txt "Built target lte-softmodem" ./enb_usrp_rh_row1.html
        summary_table_row "Coding - Release 15" ./archives/red_hat/coding.Rel15.txt "Built target coding" ./enb_usrp_rh_row2.html
        summary_table_row "OAI USRP device if - Release 15" ./archives/red_hat/oai_usrpdevif.Rel15.txt "Built target oai_usrpdevif" ./enb_usrp_rh_row3.html
        summary_table_row "Parameters Lib Config - Release 15" ./archives/red_hat/params_libconfig.Rel15.txt "Built target params_libconfig" ./enb_usrp_rh_row4.html
        summary_table_footer
    fi

    echo "   <h3>Details</h3>" >> ./build_results.html
    echo "   <button data-toggle=\"collapse\" data-target=\"#oai-compilation-details\">Details for Compilation Errors and Warnings </button>" >> ./build_results.html
    echo "   <div id=\"oai-compilation-details\" class=\"collapse\">" >> ./build_results.html

    if [ -f ./enb_eth_row1.html ] || [ -f ./enb_eth_row2.html ] || [ -f ./enb_eth_row3.html ] || [ -f ./enb_eth_row4.html ] || [ -f ./enb_eth_row5.html ] || [ -f ./enb_eth_row6.html ] || [ -f ./enb_eth_row7.html ]
    then
        for DETAILS_TABLE in `ls ./enb_eth_row*.html`
        do
            cat $DETAILS_TABLE >> ./build_results.html
        done
    fi
    if [ -f ./ue_eth_row1.html ] || [ -f ./ue_eth_row2.html ] || [ -f ./ue_eth_row3.html ] || [ -f ./ue_eth_row4.html ] || [ -f ./ue_eth_row5.html ] || [ -f ./ue_eth_row6.html ] || [ -f ./ue_eth_row7.html ] || [ -f ./ue_eth_row8.html ] || [ -f ./ue_eth_row9.html ] || [ -f ./ue_eth_row9a.html ] || [ -f ./ue_eth_row9b.html ]
    then
        for DETAILS_TABLE in `ls ./ue_eth_row*.html`
        do
            cat $DETAILS_TABLE >> ./build_results.html
        done
    fi
    if [ -f ./gnb_usrp_row1.html ] || [ -f ./gnb_usrp_row2.html ] || [ -f ./gnb_usrp_row3.html ] || [ -f ./gnb_usrp_row4.html ]
    then 
        for DETAILS_TABLE in `ls ./gnb_usrp_row*.html`
        do
            cat $DETAILS_TABLE >> ./build_results.html
        done
    fi
    if [ -f ./nr_ue_usrp_row1.html ] || [ -f ./nr_ue_usrp_row2.html ] || [ -f ./nr_ue_usrp_row3.html ] || [ -f ./nr_ue_usrp_row4.html ]
    then
        for DETAILS_TABLE in `ls ./nr_ue_usrp_row*.html`
        do
            cat $DETAILS_TABLE >> ./build_results.html
        done
    fi
    rm -f ./*_row*.html

    echo "   </div>" >> ./build_results.html
    echo "   <p></p>" >> ./build_results.html
    echo "   <div class=\"well well-lg\">End of Build Report -- Copyright <span class=\"glyphicon glyphicon-copyright-mark\"></span> 2018 <a href=\"http://www.openairinterface.org/\">OpenAirInterface</a>. All Rights Reserved.</div>" >> ./build_results.html
    echo "</div></body>" >> ./build_results.html
    echo "</html>" >> ./build_results.html
}
