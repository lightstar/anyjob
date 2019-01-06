/**
 * Define 'summaryDialog' component used to input summary name via modal dialog.
 * Usage:
 *     $uibModal.open({
           component: 'summaryDialog',
           resolve: {
               summary: function() {
                   return '...';
               }
            }
       }).result.then(function (summary) { ... }, function() { ... });
 *
 * Author:       LightStar
 * Created:      27.12.2018
 * Last update:  06.01.2019
 */

app.component('summaryDialog', {
    bindings: {
        resolve: '<',
        close: '&',
        dismiss: '&'
    },

    controller: function (focus) {
        var $ctrl = this;

        /**
         * Initialize component.
         */
        $ctrl.$onInit = function () {
            $ctrl.id = guidGenerator();
            $ctrl.summary = $ctrl.resolve.summary || '';
            focus('id-' + $ctrl.id);
        };

        /**
         * Callback function called when user clicks 'Ok' button.
         */
        $ctrl.onOk = function () {
            if ($ctrl.summary !== '') {
                $ctrl.close({$value: $ctrl.summary});
            }
        };

        /**
         * Callback function called when user clicks 'Cancel' button.
         */
        $ctrl.onCancel = function () {
            $ctrl.dismiss({$value: null});
        };
    },

    templateUrl: 'app/components/dialog/summary/template.html'
});
